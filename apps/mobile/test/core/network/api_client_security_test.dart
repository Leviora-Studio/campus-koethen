// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:campus_koethen/core/network/api_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_http_adapter.dart';

void main() {
  test('Campus API reads never follow server-selected redirects', () async {
    final FakeHttpAdapter adapter = FakeHttpAdapter(
      (_) => FakeHttpResponse(envelope(<Object>[])),
    );
    final ApiClient client = fakeApiClient(adapter);

    await client.get<List<Object>>('/posts', parse: (_) => const <Object>[]);

    final RequestOptions request = adapter.requests.single;
    expect(request.followRedirects, isFalse);
  });
}
