// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'dart:convert';
import 'dart:io';

import 'package:campus_koethen/features/requests/application/requests_providers.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// The client every requests call shares must not let the far end choose the
/// next host.
///
/// Dio follows redirects by default. Measured against a local server with the
/// old options: a `303` on a `POST` is followed cross-host as a `GET` that
/// still carries the request headers, and every `GET` redirect is followed
/// outright. `CaseDocumentDownloader` refused that per request; the policy
/// belongs on the shared client, which is what this asserts.
void main() {
  late HttpServer elsewhere;
  late HttpServer origin;
  late List<String> reachedElsewhere;

  setUp(() async {
    reachedElsewhere = <String>[];

    elsewhere = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    elsewhere.listen((HttpRequest request) async {
      await utf8.decoder.bind(request).join();
      reachedElsewhere.add('${request.method} ${request.uri.path}');
      request.response
        ..statusCode = 200
        ..write('{}');
      await request.response.close();
    });

    origin = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  });

  tearDown(() async {
    await elsewhere.close(force: true);
    await origin.close(force: true);
  });

  void answerWith(int status) {
    origin.listen((HttpRequest request) async {
      await utf8.decoder.bind(request).join();
      request.response
        ..statusCode = status
        ..headers.set(
          'location',
          'http://${elsewhere.address.host}:${elsewhere.port}/stolen',
        );
      await request.response.close();
    });
  }

  Dio buildClient() {
    final ProviderContainer container = ProviderContainer();
    addTearDown(container.dispose);
    return container.read(requestsDioProvider);
  }

  // 303 is the one a POST used to follow; the others cover the whole family.
  for (final int status in <int>[301, 302, 303, 307, 308]) {
    test('a $status on a POST is not followed to another host', () async {
      answerWith(status);
      final Dio dio = buildClient();

      final Response<dynamic> response = await dio.post<dynamic>(
        'http://${origin.address.host}:${origin.port}/api/public/v1/status',
        data: <String, dynamic>{'statusUrl': 'a-secret-link'},
        options: Options(
          headers: <String, String>{'Idempotency-Key': 'a-secret-key'},
          contentType: Headers.jsonContentType,
        ),
      );

      expect(response.statusCode, status);
      expect(
        reachedElsewhere,
        isEmpty,
        reason: 'the redirect target must never be contacted',
      );
    });

    test('a $status on a GET is not followed to another host', () async {
      answerWith(status);
      final Dio dio = buildClient();

      final Response<dynamic> response = await dio.get<dynamic>(
        'http://${origin.address.host}:${origin.port}/api/public/v1/locations',
      );

      expect(response.statusCode, status);
      expect(reachedElsewhere, isEmpty);
    });
  }
}
