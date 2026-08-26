// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:campus_koethen/features/grades/data/legacy_qis_gateway.dart';
import 'package:campus_koethen/features/grades/domain/grade.dart';
import 'package:campus_koethen/features/grades/domain/grade_credentials.dart';
import 'package:campus_koethen/features/grades/domain/grade_failure.dart';
import 'package:campus_koethen/features/grades/domain/legacy_qis_profile.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_html_adapter.dart';
import 'grade_fixtures.dart';

const GradeCredentials _creds = GradeCredentials(
  username: 'testuser',
  password: 'test-pw',
);

/// The default happy-path script: login → portal → Prüfungsverwaltung →
/// Notenspiegel → (logout).
FakeHtmlResponse _happyPath(RequestOptions o) {
  final String url = o.uri.toString();
  if (url.contains('auth.login')) {
    return const FakeHtmlResponse(portalStartHtml);
  }
  if (url.contains('auth.logout')) {
    return const FakeHtmlResponse('bye');
  }
  if (url.contains('state=change')) {
    return const FakeHtmlResponse(pruefungsverwaltungHtml);
  }
  if (url.contains('notenspiegelStudent')) {
    return const FakeHtmlResponse(notenspiegelHtml);
  }
  return const FakeHtmlResponse('not found', statusCode: 404);
}

void main() {
  test(
    'logs in form-urlencoded (asdf/fdsa) to the HTTPS portal host',
    () async {
      final adapter = FakeHtmlAdapter(_happyPath);
      final gateway = LegacyQisGradesGateway(const LegacyQisProfile(), adapter);

      final GradeReport report = await gateway.fetchGrades(_creds);
      expect(report.entries, hasLength(8));

      final RequestOptions login = adapter.requests.firstWhere(
        (RequestOptions o) => o.uri.toString().contains('auth.login'),
      );
      expect(login.method, 'POST');
      expect(login.contentType, contains('application/x-www-form-urlencoded'));
      expect(login.data, <String, String>{
        'asdf': 'testuser',
        'fdsa': 'test-pw',
      });
      expect(login.uri.scheme, 'https');
      expect(login.uri.host, 'service.ssc.hs-anhalt.de');
    },
  );

  test('uses the session asi from the links and logs out afterwards', () async {
    final adapter = FakeHtmlAdapter(_happyPath);
    await LegacyQisGradesGateway(
      const LegacyQisProfile(),
      adapter,
    ).fetchGrades(_creds);

    expect(
      adapter.urls.any(
        (String u) =>
            u.contains('state=change') && u.contains('asi=SID-ABC-123'),
      ),
      isTrue,
      reason: 'navigation must carry the dynamic session asi',
    );
    expect(adapter.urls.any((String u) => u.contains('auth.logout')), isTrue);
  });

  test('rejects a redirect to another host', () async {
    final adapter = FakeHtmlAdapter((RequestOptions o) {
      if (o.uri.toString().contains('auth.login')) {
        return const FakeHtmlResponse.redirect(
          'https://evil.example.com/steal',
        );
      }
      return const FakeHtmlResponse('bye');
    });
    await expectLater(
      LegacyQisGradesGateway(
        const LegacyQisProfile(),
        adapter,
      ).fetchGrades(_creds),
      throwsA(
        isA<GradeFailure>().having(
          (GradeFailure e) => e.kind,
          'kind',
          GradeFailureKind.tlsOrHostRejected,
        ),
      ),
    );
  });

  test('rejects a redirect that downgrades to HTTP', () async {
    final adapter = FakeHtmlAdapter((RequestOptions o) {
      if (o.uri.toString().contains('auth.login')) {
        return const FakeHtmlResponse.redirect(
          'http://service.ssc.hs-anhalt.de/qisserver/rds?x=1',
        );
      }
      return const FakeHtmlResponse('bye');
    });
    await expectLater(
      LegacyQisGradesGateway(
        const LegacyQisProfile(),
        adapter,
      ).fetchGrades(_creds),
      throwsA(
        isA<GradeFailure>().having(
          (GradeFailure e) => e.kind,
          'kind',
          GradeFailureKind.tlsOrHostRejected,
        ),
      ),
    );
  });

  test('detects invalid credentials (login form returned on 200)', () async {
    final adapter = FakeHtmlAdapter((RequestOptions o) {
      if (o.uri.toString().contains('auth.login')) {
        // HTTP 200 but the login form is shown again → NOT a success.
        return const FakeHtmlResponse(loginFormHtml);
      }
      return const FakeHtmlResponse('bye');
    });
    await expectLater(
      LegacyQisGradesGateway(
        const LegacyQisProfile(),
        adapter,
      ).fetchGrades(_creds),
      throwsA(
        isA<GradeFailure>().having(
          (GradeFailure e) => e.kind,
          'kind',
          GradeFailureKind.invalidCredentials,
        ),
      ),
    );
  });

  test(
    'logs out and maps a structure change even after a parser error',
    () async {
      final adapter = FakeHtmlAdapter((RequestOptions o) {
        final String url = o.uri.toString();
        if (url.contains('auth.login')) {
          return const FakeHtmlResponse(portalStartHtml);
        }
        if (url.contains('auth.logout')) {
          return const FakeHtmlResponse('bye');
        }
        if (url.contains('state=change')) {
          return const FakeHtmlResponse(pruefungsverwaltungHtml);
        }
        if (url.contains('notenspiegelStudent')) {
          // Structure changed: a table with the wrong headers.
          return const FakeHtmlResponse(structureChangedHtml);
        }
        return const FakeHtmlResponse('not found', statusCode: 404);
      });
      final gateway = LegacyQisGradesGateway(const LegacyQisProfile(), adapter);

      late final Object caught;
      try {
        await gateway.fetchGrades(_creds);
        fail('expected a failure');
      } catch (e) {
        caught = e;
      }
      expect(
        caught,
        isA<GradeFailure>().having(
          (GradeFailure e) => e.kind,
          'kind',
          GradeFailureKind.portalStructureChanged,
        ),
      );
      // The failure text carries no HTML and no secrets.
      expect(caught.toString(), 'GradeFailure(portalStructureChanged)');
      // Logout happened despite the error.
      expect(adapter.urls.any((String u) => u.contains('auth.logout')), isTrue);
    },
  );
}
