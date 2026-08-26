// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

/// Reading a case's state — and keeping the link out of everywhere it must not
/// appear.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:campus_koethen/features/requests/data/case_document_downloader.dart';
import 'package:campus_koethen/features/requests/data/gremio_status_gateway.dart';
import 'package:campus_koethen/features/requests/domain/case_status.dart';
import 'package:campus_koethen/features/requests/domain/status_gateway.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_gremio.dart';
import '../../support/fake_bytes_adapter.dart';

(GremioStatusGateway, FakeGremioAdapter) _build(
  FakeGremioResponse Function(RequestOptions) handler, {
  String baseUrl = kFakeBaseUrl,
}) {
  final FakeGremioAdapter adapter = FakeGremioAdapter(handler);
  return (
    GremioStatusGateway(dio: fakeGremioDio(adapter), baseUrl: baseUrl),
    adapter,
  );
}

void main() {
  group('the request itself', () {
    test('is a POST with the link in the JSON body only', () async {
      final (gateway, adapter) = _build(
        (_) => FakeGremioResponse(applicationStatusBody()),
      );

      await gateway.fetch(kFakeStatusUrl);

      expect(adapter.lastRequest.method, 'POST');
      expect(adapter.lastRequest.followRedirects, isFalse);
      expect(adapter.lastRequest.path, contains('/api/public/v1/status'));
      expect(adapter.lastRequest.contentType, contains('application/json'));
      // The whole reason this is a POST: a query parameter would put a bearer
      // credential into proxy logs, access logs and browser history.
      expect(adapter.lastRequest.uri.query, isEmpty);
      expect(adapter.lastRequest.uri.toString(), isNot(contains('testtoken')));
      expect(jsonDecode(adapter.bodies.last), <String, dynamic>{
        'statusUrl': kFakeStatusUrl,
      });
    });

    test('carries no idempotency key — it changes nothing', () async {
      final (gateway, adapter) = _build(
        (_) => FakeGremioResponse(applicationStatusBody()),
      );

      await gateway.fetch(kFakeStatusUrl);

      expect(
        adapter.lastRequest.headers.containsKey('Idempotency-Key'),
        isFalse,
      );
    });

    test('never sends a link that belongs to another origin', () async {
      final (gateway, adapter) = _build(
        (_) => FakeGremioResponse(applicationStatusBody()),
      );

      final StatusResult result = await gateway.fetch(
        'https://attacker.invalid/status/abc',
      );

      expect(result, isA<StatusLinkInvalid>());
      expect(
        adapter.requests,
        isEmpty,
        reason: 'not even our own endpoint gets to see a foreign link',
      );
    });
  });

  group('the documented answers', () {
    Future<StatusResult> answer(FakeGremioResponse response) async {
      final (gateway, _) = _build((_) => response);
      return gateway.fetch(kFakeStatusUrl);
    }

    test('200 parses an application', () async {
      final StatusResult result = await answer(
        FakeGremioResponse(applicationStatusBody()),
      );

      expect(result, isA<StatusLoaded>());
      expect((result as StatusLoaded).status, isA<ApplicationCaseStatus>());
    });

    test('200 parses a feedback', () async {
      final StatusResult result = await answer(
        FakeGremioResponse(feedbackStatusBody()),
      );

      expect((result as StatusLoaded).status, isA<FeedbackCaseStatus>());
    });

    test('400 is an invalid link, and never deletes anything', () async {
      expect(
        await answer(const FakeGremioResponse(null, statusCode: 400)),
        isA<StatusLinkInvalid>(),
      );
    });

    test('404 is "not found", which is not "delete this record"', () async {
      // The endpoint answers 404 identically for an unknown token, a deleted
      // case and a token of the wrong type. Acting on it would strand a case.
      expect(
        await answer(const FakeGremioResponse(null, statusCode: 404)),
        isA<StatusNotFound>(),
      );
    });

    test('429 carries Retry-After', () async {
      final StatusResult result = await answer(
        const FakeGremioResponse(
          null,
          statusCode: 429,
          headers: <String, String>{'Retry-After': '30'},
        ),
      );

      expect(result, isA<StatusRateLimited>());
      expect(
        (result as StatusRateLimited).retryAfter,
        const Duration(seconds: 30),
      );
    });

    test('413 and 415 are protocol faults, reported as unavailable', () async {
      expect(
        await answer(const FakeGremioResponse(null, statusCode: 413)),
        isA<StatusUnavailable>(),
      );
      expect(
        await answer(const FakeGremioResponse(null, statusCode: 415)),
        isA<StatusUnavailable>(),
      );
    });

    test('500 and transport errors are temporary', () async {
      expect(
        await answer(const FakeGremioResponse(null, statusCode: 500)),
        isA<StatusUnavailable>(),
      );
      expect(
        await answer(const FakeGremioResponse.transportError()),
        isA<StatusUnavailable>(),
      );
    });

    test('an unreadable body is a read failure, not a missing case', () async {
      expect(
        await answer(const FakeGremioResponse(<String, dynamic>{'type': 'x'})),
        isA<StatusUnavailable>(),
      );
    });

    test('no error reason carries the link', () async {
      final StatusResult result = await answer(
        const FakeGremioResponse.transportError(),
      );
      expect(
        (result as StatusUnavailable).reason,
        isNot(contains('testtoken')),
      );
    });
  });

  test('an unconfigured build says so', () async {
    final (gateway, _) = _build(
      (_) => FakeGremioResponse(applicationStatusBody()),
      baseUrl: '',
    );

    expect(await gateway.fetch(kFakeStatusUrl), isA<StatusNotConnected>());
  });

  group('downloading a document', () {
    CaseDocumentDownloader downloader(
      FakeGremioResponse Function(RequestOptions) handler, {
      String baseUrl = kFakeBaseUrl,
    }) => CaseDocumentDownloader(
      dio: fakeGremioDio(FakeGremioAdapter(handler)),
      baseUrl: baseUrl,
    );

    test('fetches a document of the configured origin', () async {
      final DocumentResult result =
          await downloader(
            (_) => FakeGremioResponse(
              null,
              bytes: Uint8List.fromList(<int>[1, 2, 3]),
              contentType: 'application/pdf',
            ),
          ).fetch(
            url: '$kFakeBaseUrl/api/status/testtoken/attachment/12',
            filename: 'Finanzantrag.pdf',
            mimeType: 'application/pdf',
          );

      expect(result, isA<DocumentLoaded>());
      expect((result as DocumentLoaded).document.filename, 'Finanzantrag.pdf');
      expect(result.document.isPdf, isTrue);
    });

    test('refuses a foreign origin, http and credentials in the URL', () async {
      for (final String url in <String>[
        'https://attacker.invalid/file.pdf',
        'http://gremio.example/file.pdf',
        'https://user:pw@gremio.example/file.pdf',
      ]) {
        final FakeGremioAdapter adapter = FakeGremioAdapter(
          (_) => const FakeGremioResponse(null),
        );
        final DocumentResult result = await CaseDocumentDownloader(
          dio: fakeGremioDio(adapter),
          baseUrl: kFakeBaseUrl,
        ).fetch(url: url, filename: 'x.pdf', mimeType: 'application/pdf');

        expect(result, isA<DocumentRefused>(), reason: url);
        expect(adapter.requests, isEmpty, reason: url);
      }
    });

    test('refuses to follow a redirect', () async {
      // A redirect could be legitimate, but it cannot be verified without
      // following it — and the request carries a token.
      final DocumentResult result =
          await downloader(
            (_) => const FakeGremioResponse(
              null,
              statusCode: 302,
              headers: <String, String>{
                'Location': 'https://attacker.invalid/x',
              },
            ),
          ).fetch(
            url: '$kFakeBaseUrl/file.pdf',
            filename: 'x.pdf',
            mimeType: 'application/pdf',
          );

      expect(result, isA<DocumentRefused>());
    });

    test('refuses a document larger than the viewer can hold', () async {
      final DocumentResult result =
          await downloader(
            (_) => FakeGremioResponse(
              null,
              bytes: Uint8List(26 * 1024 * 1024),
              contentType: 'application/pdf',
            ),
          ).fetch(
            url: '$kFakeBaseUrl/file.pdf',
            filename: 'x.pdf',
            mimeType: 'application/pdf',
          );

      expect(result, isA<DocumentTooLarge>());
    });

    test(
      'stops reading as soon as the document crosses the size limit',
      () async {
        int chunksRead = 0;
        final FakeBytesAdapter adapter = FakeBytesAdapter(
          (_) => FakeBytes(
            <Uint8List>[
              Uint8List(13 * 1024 * 1024),
              Uint8List(13 * 1024 * 1024),
              Uint8List(1024),
            ],
            contentType: 'application/pdf',
            onChunkRead: (_) => chunksRead++,
          ),
        );
        final Dio dio = Dio()..httpClientAdapter = adapter;

        final DocumentResult result =
            await CaseDocumentDownloader(dio: dio, baseUrl: kFakeBaseUrl).fetch(
              url: '$kFakeBaseUrl/file.pdf',
              filename: 'x.pdf',
              mimeType: 'application/pdf',
            );

        expect(result, isA<DocumentTooLarge>());
        expect(
          chunksRead,
          2,
          reason:
              'the third chunk must never be pulled after the cap is crossed',
        );
      },
    );

    test('never puts the URL in a failure reason', () async {
      final DocumentResult result =
          await downloader(
            (_) => const FakeGremioResponse.transportError(),
          ).fetch(
            url: '$kFakeBaseUrl/status/testtoken/pdf',
            filename: 'x.pdf',
            mimeType: 'application/pdf',
          );

      expect(
        (result as DocumentUnavailable).reason,
        isNot(contains('testtoken')),
      );
    });
  });
}
