// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:dio/dio.dart';

import 'api_config.dart';
import 'api_failure.dart';
import 'api_meta.dart';
import 'json.dart';

/// Thin typed wrapper around `dio` for the Campus API.
///
/// Responsibilities:
/// * attach the resolved locale to every request,
/// * unwrap the `{ data, meta }` envelope,
/// * translate transport errors into [ApiFailure].
///
/// It knows nothing about Strapi or any upstream data source — the app only
/// ever talks to `/v1` of the Campus API.
class ApiClient {
  ApiClient({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: ApiConfig.root,
              connectTimeout: ApiConfig.connectTimeout,
              receiveTimeout: ApiConfig.receiveTimeout,
              responseType: ResponseType.json,
              headers: const <String, String>{'Accept': 'application/json'},
            ),
          );

  final Dio _dio;

  Dio get dio => _dio;

  /// Performs a `GET` and parses the envelope.
  ///
  /// [query] entries with a `null` value are dropped, which is how a parameter
  /// can be *omitted*. An empty string value is preserved on purpose — the
  /// `channels=` contract depends on the difference between "absent" and
  /// "present but empty".
  Future<ApiResponse<T>> get<T>(
    String path, {
    required T Function(Object? data) parse,
    Map<String, Object?> query = const <String, Object?>{},
    String? locale,
  }) async {
    final Map<String, Object?> parameters = <String, Object?>{};
    for (final MapEntry<String, Object?> entry in query.entries) {
      final Object? value = entry.value;
      if (value != null) parameters[entry.key] = value;
    }
    if (locale != null) parameters['locale'] = locale;

    try {
      final Response<dynamic> response = await _dio.get<dynamic>(
        path,
        queryParameters: parameters,
        // The configured API origin decides the network boundary. A response
        // must not silently replace it with a second host, even though these
        // public reads carry no authentication token.
        options: Options(followRedirects: false),
      );
      final Map<String, dynamic>? body = asJsonMap(response.data);
      if (body == null) {
        throw const ApiFailure(kind: ApiFailureKind.unknown);
      }
      return ApiResponse<T>(
        data: parse(body['data']),
        meta: ApiMeta.fromJson(body['meta']),
      );
    } on DioException catch (error) {
      throw _toFailure(error);
    } on ApiFailure {
      rethrow;
    } catch (_) {
      throw const ApiFailure(kind: ApiFailureKind.unknown);
    }
  }

  static ApiFailure _toFailure(DioException error) {
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
        return const ApiFailure(kind: ApiFailureKind.timeout);
      case DioExceptionType.connectionError:
      case DioExceptionType.cancel:
        return const ApiFailure(kind: ApiFailureKind.network);
      case DioExceptionType.badCertificate:
        return const ApiFailure(kind: ApiFailureKind.network);
      case DioExceptionType.badResponse:
      case DioExceptionType.unknown:
        break;
    }

    final int? status = error.response?.statusCode;
    final Map<String, dynamic>? errorBody = asJsonMap(
      asJsonMap(error.response?.data)?['error'],
    );
    final String? code = asString(errorBody?['code']);

    if (status == null) {
      return const ApiFailure(kind: ApiFailureKind.network);
    }
    if (status == 404) {
      return ApiFailure(
        kind: ApiFailureKind.notFound,
        code: code,
        statusCode: status,
      );
    }
    if (status == 504) {
      return ApiFailure(
        kind: ApiFailureKind.timeout,
        code: code,
        statusCode: status,
      );
    }
    if (status >= 500) {
      return ApiFailure(
        kind: ApiFailureKind.server,
        code: code,
        statusCode: status,
      );
    }
    if (status >= 400) {
      return ApiFailure(
        kind: ApiFailureKind.badRequest,
        code: code,
        statusCode: status,
      );
    }
    return ApiFailure(
      kind: ApiFailureKind.unknown,
      code: code,
      statusCode: status,
    );
  }
}
