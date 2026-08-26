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
import 'qis_html_parser.dart';

/// One fetched page: its final URL and HTML.
class _Page {
  const _Page(this.url, this.html);
  final String url;
  final String html;
}

/// Talks to HIS-QIS over HTTPS, ONLY to the pinned host.
///
/// Security posture, enforced here and nowhere else:
///  - Every request URL is validated to be HTTPS on exactly the portal host;
///    a redirect to another host or to HTTP is refused (`tlsOrHostRejected`).
///  - Certificate validation is NEVER disabled; there is no `onBadCertificate`
///    and no "accept all certificates".
///  - The cookie jar is in-memory and per fetch; cookies and `asi` never touch
///    disk. In `finally` the logout link is called (best effort) and the jar is
///    emptied.
///  - No dio LogInterceptor; credentials, cookies, `asi` and HTML are never
///    logged, and every raw error is mapped to a [GradeFailure] that carries
///    only the classification.
class LegacyQisGradesGateway implements GradesGateway {
  /// [adapter] is a test-only injection point (positional so it can stay a
  /// private field). In production the default IO adapter — full TLS validation
  /// — is used.
  LegacyQisGradesGateway(this._profile, [this._adapter]);

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
      // Default IO adapter — NO onBadCertificate override, so certificate and
      // hostname validation stay fully enabled.
      dio.httpClientAdapter = IOHttpClientAdapter();
    }

    String? logoutHref;
    try {
      // 1) Login (form-urlencoded asdf/fdsa) → follow to the landing page.
      final _Page landing = await _follow(
        dio,
        await dio.postUri(
          _validated(_profile.loginUrl),
          data: <String, String>{
            'asdf': credentials.username,
            'fdsa': credentials.password,
          },
          options: Options(contentType: Headers.formUrlEncodedContentType),
        ),
      );
      if (await QisHtmlParser.hasLoginForm(landing.html)) {
        throw const GradeFailure(GradeFailureKind.invalidCredentials);
      }
      logoutHref = await QisHtmlParser.logoutHref(landing.html);

      // 2) Prüfungsverwaltung (the link carries the session asi).
      final String? verwaltungHref = await QisHtmlParser.findLinkHref(
        landing.html,
        labels: <String>['prüfungsverwaltung'],
      );
      final _Page verwaltung = await _open(dio, verwaltungHref);
      logoutHref =
          await QisHtmlParser.logoutHref(verwaltung.html) ?? logoutHref;

      // 3) Notenspiegel.
      final String? notenspiegelHref = await QisHtmlParser.findLinkHref(
        verwaltung.html,
        labels: <String>['notenspiegel'],
      );
      _Page notenspiegel = await _open(dio, notenspiegelHref);
      logoutHref =
          await QisHtmlParser.logoutHref(notenspiegel.html) ?? logoutHref;

      // 4) Parse. If the table is not on this page yet, follow one more link to
      //    the actual list of results before giving up.
      try {
        return await QisHtmlParser.parseGradeReport(notenspiegel.html);
      } on GradeFailure {
        final String? deeper = await QisHtmlParser.findLinkHref(
          notenspiegel.html,
          labels: <String>['notenspiegel', 'leistung', 'anzeigen'],
        );
        if (deeper == null) rethrow;
        notenspiegel = await _open(dio, deeper);
        logoutHref =
            await QisHtmlParser.logoutHref(notenspiegel.html) ?? logoutHref;
        return await QisHtmlParser.parseGradeReport(notenspiegel.html);
      }
    } on GradeFailure {
      rethrow;
    } on DioException catch (e) {
      throw _mapDio(e);
    } catch (_) {
      // Never re-throw a raw error that could carry HTML or secrets.
      throw const GradeFailure(GradeFailureKind.unknown);
    } finally {
      // Best effort: log out, then wipe every session trace.
      if (logoutHref != null) {
        try {
          await _open(dio, logoutHref);
        } catch (_) {}
      }
      try {
        await jar.deleteAll();
      } catch (_) {}
      dio.close(force: true);
    }
  }

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

  /// GETs [rawUrl] (a session link) and follows redirects to an HTML page.
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
      // 4xx and anything else.
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
        // A TLS handshake failure surfaces as unknown with a HandshakeException.
        final Object? inner = e.error;
        if (inner is Exception &&
            inner.runtimeType.toString().contains('Handshake')) {
          return const GradeFailure(GradeFailureKind.tlsOrHostRejected);
        }
        return const GradeFailure(GradeFailureKind.networkUnavailable);
    }
  }
}
