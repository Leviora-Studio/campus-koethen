// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';

import '../domain/grade.dart';
import '../domain/grade_credentials.dart';
import '../domain/grade_failure.dart';
import '../domain/grade_portal_profile.dart';
import '../domain/grades_gateway.dart';
import 'his_in_one_html_parser.dart';

/// One fetched page: its final URL, HTML and raw headers (for cookie/location
/// inspection where needed).
class _Page {
  const _Page(this.url, this.html);
  final String url;
  final String html;
}

/// Talks to the HISinOne exam portal over HTTPS, ONLY to the pinned host.
///
/// Same security posture as [LegacyQisGradesGateway], enforced independently
/// here (deliberately no shared allowlist):
///  - Every request URL is validated to be HTTPS on exactly the portal host; a
///    redirect to another host or to HTTP is refused (`tlsOrHostRejected`).
///  - Certificate validation is NEVER disabled.
///  - The cookie jar is in-memory and per fetch. In `finally` the logout
///    endpoint is called (best effort) and the jar is emptied.
///  - No dio LogInterceptor; credentials, cookies, `authenticity_token`,
///    `ViewState` and HTML are never logged.
///
/// The flow is at most four requests: login (POST), the exam overview (GET),
/// "expand all" (POST, with every hidden field taken from the loaded page —
/// nothing hard-coded, and only when that control exists in this portal
/// build), and logout (GET, `finally`).
class HisInOneGradesGateway implements GradesGateway {
  HisInOneGradesGateway(this._profile, [this._adapter]);

  final GradePortalProfile _profile;
  final HttpClientAdapter? _adapter;

  static const Duration _timeout = Duration(seconds: 20);
  static const int _maxHops = 10;

  @override
  Future<GradeReport> fetchGrades(GradeCredentials credentials) async {
    final CookieJar jar = CookieJar(); // in-memory only
    final Dio dio = Dio(
      BaseOptions(
        connectTimeout: _timeout,
        receiveTimeout: _timeout,
        sendTimeout: _timeout,
        responseType: ResponseType.plain,
        followRedirects: false, // redirects are validated by hand
        validateStatus: (_) => true, // status handled explicitly below
        headers: const <String, String>{'User-Agent': 'CampusKoethen/grades'},
      ),
    );
    dio.interceptors.add(CookieManager(jar));
    if (_adapter != null) {
      dio.httpClientAdapter = _adapter;
    } else {
      // Default IO adapter — NO onBadCertificate override.
      dio.httpClientAdapter = IOHttpClientAdapter();
    }

    try {
      // 1) Login (form-urlencoded asdf/fdsa). The portal ALWAYS answers 302.
      final Response<dynamic> loginResponse = await dio.postUri(
        _validated(_profile.loginUrl),
        data: <String, String>{
          'asdf': credentials.username,
          'fdsa': credentials.password,
        },
        options: Options(contentType: Headers.formUrlEncodedContentType),
      );
      final int loginStatus = loginResponse.statusCode ?? 0;
      if (loginStatus < 300 || loginStatus >= 400) {
        throw const GradeFailure(GradeFailureKind.portalUnavailable);
      }
      final String location = loginResponse.headers.value('location') ?? '';
      if (location.isEmpty) {
        throw const GradeFailure(GradeFailureKind.portalStructureChanged);
      }
      // Validate the redirect target BEFORE inspecting it for the
      // success/fail signal: a malicious redirect to another host or to HTTP
      // must always surface as `tlsOrHostRejected`, never be reclassified as
      // an ordinary login failure just because it lacks the expected marker.
      final Uri target = _validated(location);
      if (location.contains('hisinoneStartPage.faces')) {
        throw const GradeFailure(GradeFailureKind.invalidCredentials);
      }
      if (!location.contains('category=menu.browse')) {
        throw const GradeFailure(GradeFailureKind.invalidCredentials);
      }
      final _Page landing = await _follow(dio, await dio.getUri(target));
      // Extra safeguard, checked POSITIVELY: HISinOne renders a hidden
      // `sessionTimeoutLoginForm` (fields `asdf`/`fdsa`) on every page, even
      // when logged in, so testing for the login form's ABSENCE is always
      // false-positive on this portal. Only a logout link proves the session
      // actually authenticated.
      if (!await HisInOneHtmlParser.isAuthenticated(landing.html)) {
        throw const GradeFailure(GradeFailureKind.invalidCredentials);
      }

      // 2) The (collapsed) exam overview.
      final _Page overview = await _open(dio, _examOverviewUrl());

      // 3) Decide what this page actually is before touching it. An account
      //    with no exam results on THIS portal renders the Leistungsdaten
      //    section with "Es wurden keine Datensätze gefunden" — no tree and no
      //    expand-all button. That is an EMPTY report, not a structure change:
      //    reporting it as a failure aborted setup before the other portal was
      //    ever tried, which is exactly how a working account ended up with no
      //    grades at all.
      final HisInOneOverview classified = await HisInOneHtmlParser.readOverview(
        overview.html,
      );
      switch (classified.kind) {
        case HisInOneOverviewKind.unrecognised:
          throw const GradeFailure(GradeFailureKind.portalStructureChanged);
        case HisInOneOverviewKind.empty:
          return const GradeReport(<GradeEntry>[]);
        case HisInOneOverviewKind.rendered:
          // No expand-all control in this portal build — parse as rendered.
          return await HisInOneHtmlParser.parseGradeReport(overview.html);
        case HisInOneOverviewKind.expandable:
          break;
      }

      // 4) Expand the tree: POST every hidden field from the loaded page plus
      //    the expand-all button, to the form's own action.
      final HisInOneExpandRequest expand = classified.expandRequest!;
      final _Page expanded = await _follow(
        dio,
        await dio.postUri(
          _validated(expand.action),
          data: expand.formData,
          options: Options(contentType: Headers.formUrlEncodedContentType),
        ),
      );

      // 5) Parse. If expanding emptied the section, that is still an empty
      //    report rather than a structure change.
      final HisInOneOverview afterExpand =
          await HisInOneHtmlParser.readOverview(expanded.html);
      if (afterExpand.kind == HisInOneOverviewKind.empty) {
        return const GradeReport(<GradeEntry>[]);
      }
      return await HisInOneHtmlParser.parseGradeReport(expanded.html);
    } on GradeFailure {
      rethrow;
    } on DioException catch (e) {
      throw _mapDio(e);
    } catch (_) {
      // Never re-throw a raw error that could carry HTML or secrets.
      throw const GradeFailure(GradeFailureKind.unknown);
    } finally {
      // Best effort: log out, then wipe every session trace.
      try {
        await dio.getUri(_validated(_profile.logoutUrl));
      } catch (_) {}
      try {
        await jar.deleteAll();
      } catch (_) {}
      dio.close(force: true);
    }
  }

  String _examOverviewUrl() =>
      '${_profile.baseUrl}/qisserver/pages/sul/examAssessment/'
      'personExamsReadonly.xhtml?_flowId=examsOverviewForPerson-flow';

  /// Validates a URL is HTTPS on the pinned host, resolving relative links
  /// against the portal base. Refuses anything else.
  Uri _validated(String raw) {
    Uri uri = Uri.parse(raw);
    if (!uri.hasScheme) {
      uri = Uri.parse(_profile.baseUrl).resolveUri(uri);
    }
    if (!_profile.allows(uri)) {
      throw const GradeFailure(GradeFailureKind.tlsOrHostRejected);
    }
    return uri;
  }

  Future<_Page> _open(Dio dio, String? rawUrl) async {
    if (rawUrl == null || rawUrl.isEmpty) {
      throw const GradeFailure(GradeFailureKind.portalStructureChanged);
    }
    return _follow(dio, await dio.getUri(_validated(rawUrl)));
  }

  /// Follows redirects from an initial response to a 2xx HTML page, validating
  /// every hop's target.
  Future<_Page> _follow(Dio dio, Response<dynamic> initial) async {
    Response<dynamic> current = initial;
    for (int hop = 0; hop < _maxHops; hop++) {
      final int code = current.statusCode ?? 0;
      if (code >= 200 && code < 300) {
        return _Page(
          current.requestOptions.uri.toString(),
          current.data?.toString() ?? '',
        );
      }
      if (code >= 300 && code < 400) {
        final String? location = current.headers.value('location');
        if (location == null) {
          throw const GradeFailure(GradeFailureKind.portalStructureChanged);
        }
        current = await dio.getUri(_validated(location));
        continue;
      }
      if (code >= 500) {
        throw const GradeFailure(GradeFailureKind.portalUnavailable);
      }
      throw const GradeFailure(GradeFailureKind.portalUnavailable);
    }
    throw const GradeFailure(GradeFailureKind.portalUnavailable);
  }

  GradeFailure _mapDio(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const GradeFailure(GradeFailureKind.timeout);
      case DioExceptionType.connectionError:
        return const GradeFailure(GradeFailureKind.networkUnavailable);
      case DioExceptionType.badCertificate:
        return const GradeFailure(GradeFailureKind.tlsOrHostRejected);
      case DioExceptionType.badResponse:
        return const GradeFailure(GradeFailureKind.portalUnavailable);
      case DioExceptionType.cancel:
      case DioExceptionType.unknown:
        final Object? inner = e.error;
        if (inner is Exception &&
            inner.runtimeType.toString().contains('Handshake')) {
          return const GradeFailure(GradeFailureKind.tlsOrHostRejected);
        }
        return const GradeFailure(GradeFailureKind.networkUnavailable);
    }
  }
}
