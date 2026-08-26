// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:campus_koethen/core/network/api_client.dart';
import 'package:dio/dio.dart';

/// A scripted [HttpClientAdapter].
///
/// Requests go through the real `dio` pipeline, so query serialisation — most
/// importantly the difference between an omitted and an empty `channels`
/// parameter — is exercised exactly as in production.
class FakeHttpAdapter implements HttpClientAdapter {
  FakeHttpAdapter(this.handler);

  /// Returns the body for a request, or throws to simulate a transport error.
  final FutureOr<FakeHttpResponse> Function(RequestOptions options) handler;

  /// Every request that reached the adapter, in order.
  final List<RequestOptions> requests = <RequestOptions>[];

  /// The raw query strings of all recorded requests.
  List<String> get queries =>
      requests.map((RequestOptions options) => options.uri.query).toList();

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final FakeHttpResponse response = await handler(options);
    return ResponseBody.fromString(
      jsonEncode(response.body),
      response.statusCode,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>['application/json; charset=utf-8'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// A scripted response.
class FakeHttpResponse {
  const FakeHttpResponse(this.body, {this.statusCode = 200});

  final Object? body;
  final int statusCode;
}

/// Builds an [ApiClient] whose transport is the given adapter.
ApiClient fakeApiClient(FakeHttpAdapter adapter) {
  final Dio dio = Dio(
    BaseOptions(
      baseUrl: 'http://localhost:3000/v1',
      // A non-2xx status must reach the failure mapper instead of throwing
      // inside dio's own validation.
      validateStatus: (int? status) => status != null && status < 400,
    ),
  );
  dio.httpClientAdapter = adapter;
  return ApiClient(dio: dio);
}

/// Wraps a payload in the API's `{ data, meta }` envelope.
Map<String, dynamic> envelope(Object? data, {Map<String, dynamic>? meta}) =>
    <String, dynamic>{
      'data': data,
      'meta': <String, dynamic>{
        'requestedLocale': 'de',
        'resolvedLocale': 'de',
        'translationFallback': false,
        ...?meta,
      },
    };
