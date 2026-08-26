// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'dart:io';

import 'package:dio/dio.dart';

import '../domain/case_status.dart';
import '../domain/gremio_origin.dart';
import '../domain/status_gateway.dart';
import 'requests_api_config.dart';

/// Reads the public state of one case.
///
/// **POST, with the link in the JSON body.** The status link is a bearer
/// credential; as a query parameter it would land in proxy logs, access logs,
/// monitoring and browser history. The body keeps it out of all of them. The
/// call carries no idempotency key — it changes nothing and may be repeated.
///
/// The link is only ever sent to the configured instance's own status
/// endpoint. It is checked against the origin allowlist first: a stored link
/// that points somewhere else is not fetched and not forwarded, because doing
/// either would hand the token to whoever owns that host.
class GremioStatusGateway implements StatusGateway {
  GremioStatusGateway({required Dio dio, required String baseUrl})
    : this._(
        dio,
        RequestsApiConfig.stripTrailingSlash(baseUrl.trim()),
        GremioOrigin.parse(baseUrl),
      );

  GremioStatusGateway._(this._dio, this._base, this._origin);

  final Dio _dio;
  final String _base;
  final GremioOrigin? _origin;

  @override
  Future<StatusResult> fetch(String statusUrl) async {
    final GremioOrigin? origin = _origin;
    if (origin == null) return const StatusNotConnected();
    // A link from another origin is treated exactly like a malformed one: it
    // is never sent anywhere, not even to our own endpoint.
    if (!origin.allows(statusUrl)) return const StatusLinkInvalid();

    try {
      final Response<dynamic> response = await _dio.post<dynamic>(
        '$_base${RequestsApiConfig.statusPath}',
        data: <String, dynamic>{'statusUrl': statusUrl},
        options: Options(
          // The body contains a bearer-equivalent status link. No response may
          // choose a second destination for it, even with a custom Dio client.
          followRedirects: false,
          headers: <String, String>{'Accept': 'application/json'},
          contentType: Headers.jsonContentType,
          receiveTimeout: RequestsApiConfig.receiveTimeout,
          validateStatus: (int? status) => status != null && status < 500,
        ),
      );
      return _read(response);
    } on DioException catch (error) {
      return _readTransportError(error);
    }
  }

  StatusResult _read(Response<dynamic> response) {
    final int status = response.statusCode ?? 0;

    if (status == 200) {
      final CaseStatus? parsed = CaseStatus.fromJson(response.data);
      // A body that does not match the contract is a temporary read failure,
      // never "the case is gone".
      return parsed == null
          ? const StatusUnavailable('unreadable-body')
          : StatusLoaded(parsed);
    }

    return switch (status) {
      400 => const StatusLinkInvalid(),
      404 => const StatusNotFound(),
      429 => StatusRateLimited(
        retryAfter: _retryAfter(response.headers.value('Retry-After')),
      ),
      // 413 and 415 are protocol faults on our side. They are reported as
      // unavailable, not as a missing case — deleting a record over one would
      // destroy the only way back to it.
      _ => StatusUnavailable('http-$status'),
    };
  }

  static Duration? _retryAfter(String? header) {
    final int? seconds = int.tryParse(header?.trim() ?? '');
    return seconds == null || seconds < 0 ? null : Duration(seconds: seconds);
  }

  static StatusResult _readTransportError(DioException error) {
    final int? status = error.response?.statusCode;
    if (status != null) return StatusUnavailable('http-$status');
    return switch (error.type) {
      DioExceptionType.connectionTimeout ||
      DioExceptionType.sendTimeout ||
      DioExceptionType.receiveTimeout ||
      DioExceptionType.connectionError => const StatusUnavailable('transport'),
      DioExceptionType.unknown when error.error is SocketException =>
        const StatusUnavailable('transport'),
      // A type name, never the link.
      _ => StatusUnavailable('dio-${error.type.name}'),
    };
  }
}
