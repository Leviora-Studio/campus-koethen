// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer
//
// Security-focused tests for the Moodle HTTP client. No real network, no real
// credentials — a scripted adapter stands in for Moodle. The point of these
// tests is the non-bypassable host/token policy, not Moodle's behaviour.

import 'package:campus_koethen/features/moodle/data/moodle_http_client.dart';
import 'package:campus_koethen/features/moodle/domain/moodle_failure.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_html_adapter.dart';

MoodleHttpClient clientWith(FakeHtmlAdapter adapter) {
  final Dio dio = Dio();
  dio.httpClientAdapter = adapter;
  return MoodleHttpClient(dio: dio);
}

void main() {
  test(
    'requestToken posts form fields to token.php and returns the token',
    () async {
      final FakeHtmlAdapter adapter = FakeHtmlAdapter(
        (RequestOptions o) => const FakeHtmlResponse('{"token":"tok-123"}'),
      );
      final MoodleHttpClient client = clientWith(adapter);

      final String token = await client.requestToken(
        username: 'demo',
        password: 'secret',
      );

      expect(token, 'tok-123');
      final RequestOptions req = adapter.requests.single;
      expect(req.uri.toString(), 'https://moodle.hs-anhalt.de/login/token.php');
      expect(req.method, 'POST');
      // Credentials travel in the body, never in the query string.
      expect(req.uri.query, isEmpty);
      final Map<String, dynamic> data = req.data as Map<String, dynamic>;
      expect(data['username'], 'demo');
      expect(data['password'], 'secret');
      expect(data['service'], 'moodle_mobile_app');
    },
  );

  test('requestToken maps invalidlogin to invalidCredentials', () async {
    final FakeHtmlAdapter adapter = FakeHtmlAdapter(
      (RequestOptions o) => const FakeHtmlResponse(
        '{"error":"Invalid login","errorcode":"invalidlogin"}',
      ),
    );
    await expectLater(
      clientWith(adapter).requestToken(username: 'x', password: 'y'),
      throwsA(const MoodleFailure(MoodleFailureKind.invalidCredentials)),
    );
  });

  test(
    'REST calls send the token in the POST body, not the query string',
    () async {
      final FakeHtmlAdapter adapter = FakeHtmlAdapter(
        (RequestOptions o) => const FakeHtmlResponse(
          '{"userid":7,"username":"demo","sitename":"Demo"}',
        ),
      );
      final MoodleHttpClient client = clientWith(adapter);

      await client.getSiteInfo('tok-xyz');

      final RequestOptions req = adapter.requests.single;
      expect(req.uri.path, '/webservice/rest/server.php');
      expect(req.uri.host, 'moodle.hs-anhalt.de');
      // The token must NOT appear anywhere in the URL.
      expect(req.uri.toString(), isNot(contains('tok-xyz')));
      expect(req.uri.query, isEmpty);
      final Map<String, dynamic> data = req.data as Map<String, dynamic>;
      expect(data['wstoken'], 'tok-xyz');
      expect(data['wsfunction'], 'core_webservice_get_site_info');
      expect(data['moodlewsrestformat'], 'json');
    },
  );

  test('courses use Moodle Web\'s in-progress classification', () async {
    final FakeHtmlAdapter adapter = FakeHtmlAdapter(
      (RequestOptions o) => const FakeHtmlResponse(
        '{"courses":[{"id":1,"fullname":"Current course"}],"nextoffset":1}',
      ),
    );
    final MoodleHttpClient client = clientWith(adapter);

    final courses = await client.getCourses(token: 'tok-current');

    expect(courses.single.fullName, 'Current course');
    final RequestOptions req = adapter.requests.single;
    final Map<String, dynamic> data = req.data as Map<String, dynamic>;
    expect(
      data['wsfunction'],
      'core_course_get_enrolled_courses_by_timeline_classification',
    );
    expect(data['classification'], 'inprogress');
    expect(data, isNot(contains('userid')));
  });

  test(
    'a Moodle exception returned as HTTP 200 becomes a classified failure',
    () async {
      final FakeHtmlAdapter adapter = FakeHtmlAdapter(
        (RequestOptions o) => const FakeHtmlResponse(
          '{"exception":"moodle_exception","errorcode":"invalidtoken","message":"x"}',
        ),
      );
      await expectLater(
        clientWith(adapter).getSiteInfo('bad'),
        throwsA(const MoodleFailure(MoodleFailureKind.tokenRejected)),
      );
    },
  );

  test('a redirect is never followed with the token and is rejected', () async {
    final FakeHtmlAdapter adapter = FakeHtmlAdapter(
      (RequestOptions o) =>
          const FakeHtmlResponse.redirect('https://evil.example.com/steal'),
    );
    await expectLater(
      clientWith(adapter).getSiteInfo('tok-should-not-leak'),
      throwsA(const MoodleFailure(MoodleFailureKind.tlsOrHostRejected)),
    );
    // Exactly one request was made — the redirect target was never contacted.
    expect(adapter.requests, hasLength(1));
    expect(adapter.requests.single.uri.host, 'moodle.hs-anhalt.de');
  });

  test('a 5xx becomes serviceUnavailable', () async {
    final FakeHtmlAdapter adapter = FakeHtmlAdapter(
      (RequestOptions o) => const FakeHtmlResponse('', statusCode: 503),
    );
    await expectLater(
      clientWith(adapter).getSiteInfo('tok'),
      throwsA(const MoodleFailure(MoodleFailureKind.serviceUnavailable)),
    );
  });
}
