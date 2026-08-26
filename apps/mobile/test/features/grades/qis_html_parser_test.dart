// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:campus_koethen/features/grades/data/qis_html_parser.dart';
import 'package:campus_koethen/features/grades/domain/grade.dart';
import 'package:campus_koethen/features/grades/domain/grade_failure.dart';
import 'package:flutter_test/flutter_test.dart';

import 'grade_fixtures.dart';

void main() {
  group('login / navigation detection', () {
    test('recognises the login form and the authenticated state', () async {
      expect(await QisHtmlParser.hasLoginForm(loginFormHtml), isTrue);
      expect(await QisHtmlParser.isAuthenticated(loginFormHtml), isFalse);

      expect(await QisHtmlParser.hasLoginForm(portalStartHtml), isFalse);
      expect(await QisHtmlParser.isAuthenticated(portalStartHtml), isTrue);
    });

    test(
      'finds session links by their label, carrying the dynamic asi',
      () async {
        final String? verwaltung = await QisHtmlParser.findLinkHref(
          portalStartHtml,
          labels: <String>['prüfungsverwaltung'],
        );
        expect(verwaltung, isNotNull);
        expect(verwaltung, contains('state=change'));
        expect(QisHtmlParser.extractAsi(verwaltung!), 'SID-ABC-123');

        final String? notenspiegel = await QisHtmlParser.findLinkHref(
          pruefungsverwaltungHtml,
          labels: <String>['notenspiegel'],
        );
        expect(notenspiegel, contains('notenspiegelStudent'));

        expect(
          await QisHtmlParser.logoutHref(portalStartHtml),
          contains('auth.logout'),
        );
      },
    );
  });

  group('parseGradeReport', () {
    late GradeReport report;
    setUp(
      () async =>
          report = await QisHtmlParser.parseGradeReport(notenspiegelHtml),
    );

    GradeEntry byNumberAndDate(String number, DateTime? date) =>
        report.entries.firstWhere(
          (GradeEntry e) => e.examNumber == number && e.examDate == date,
        );

    test('identifies the grades table by its headers, ignoring the decoy', () {
      // Eight real rows; the trailing empty spacer row is dropped.
      expect(report.entries, hasLength(8));
    });

    test('reads a German decimal grade and the date (dd.MM.yyyy)', () {
      final GradeEntry e = byNumberAndDate('12345', DateTime(2026, 2, 12));
      expect(e.title, 'Grundlagen der Informatik');
      expect(e.grade.isGraded, isTrue);
      expect(e.grade.value, 1.7);
      expect(e.status, ExamStatus.passed);
      expect(e.attempt, '1');
      expect(e.examiner, 'Prof. A');
    });

    test('treats 0,0 + bestanden as passed-ungraded, never a 0.0 grade', () {
      final GradeEntry e = report.entries.firstWhere(
        (GradeEntry x) => x.examNumber == '34567',
      );
      expect(e.grade.isPassedUngraded, isTrue);
      expect(e.grade.isGraded, isFalse);
      expect(e.grade.value, isNull);
    });

    test('treats an empty grade + bestanden as passed-ungraded', () {
      final GradeEntry e = report.entries.firstWhere(
        (GradeEntry x) => x.examNumber == '45678',
      );
      expect(e.grade.isPassedUngraded, isTrue);
      // Whitespace/newlines in the title are normalised.
      expect(e.title, 'Seminar');
      expect(e.bonus, '5');
    });

    test('keeps an empty grade empty when not passed', () {
      final GradeEntry present = report.entries.firstWhere(
        (GradeEntry x) => x.examNumber == '67890',
      );
      expect(present.grade.isEmpty, isTrue);
      expect(present.status, ExamStatus.present);
      expect(present.examDate, isNull, reason: 'no date, but row is kept');
    });

    test('normalises HTML entities and maps nicht bestanden to failed', () {
      final GradeEntry e = report.entries.firstWhere(
        (GradeEntry x) => x.examNumber == '56789',
      );
      expect(e.title, 'Recht & Wirtschaft');
      expect(e.grade.value, 5.0);
      expect(e.status, ExamStatus.failed);
    });

    test('keeps an unknown status without crashing, preserving the text', () {
      final GradeEntry e = report.entries.firstWhere(
        (GradeEntry x) => x.examNumber == '78901',
      );
      expect(e.status, ExamStatus.unknown);
      expect(e.statusText, 'angemeldet');
      expect(e.grade.isEmpty, isTrue);
    });

    test('does NOT deduplicate factually different rows (retake)', () {
      final Iterable<GradeEntry> math = report.entries.where(
        (GradeEntry x) => x.title == 'Mathematik I',
      );
      expect(math, hasLength(2));
      expect(
        math.map((GradeEntry e) => e.status),
        containsAll(<ExamStatus>[ExamStatus.passed, ExamStatus.failed]),
      );
    });

    test('empty "Punkte" (incl. &nbsp;) becomes null', () {
      final GradeEntry e = byNumberAndDate('12345', DateTime(2026, 2, 12));
      expect(e.points, isNull);
    });
  });

  group('structure validation', () {
    test('missing required columns yields portalStructureChanged', () async {
      await expectLater(
        QisHtmlParser.parseGradeReport(structureChangedHtml),
        throwsA(
          isA<GradeFailure>().having(
            (GradeFailure e) => e.kind,
            'kind',
            GradeFailureKind.portalStructureChanged,
          ),
        ),
      );
    });

    test(
      'a login page (no grades table) also yields portalStructureChanged',
      () async {
        await expectLater(
          QisHtmlParser.parseGradeReport(loginFormHtml),
          throwsA(isA<GradeFailure>()),
        );
      },
    );
  });
}
