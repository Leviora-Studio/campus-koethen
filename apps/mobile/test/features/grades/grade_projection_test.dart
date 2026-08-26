// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:campus_koethen/features/grades/domain/grade.dart';
import 'package:campus_koethen/features/grades/domain/grade_projection.dart';
import 'package:flutter_test/flutter_test.dart';

GradeEntry _row(String title, {Grade grade = const Grade.none()}) => GradeEntry(
  examNumber: '1',
  title: title,
  grade: grade,
  status: ExamStatus.passed,
  statusText: 'bestanden',
);

void main() {
  group('classifying a row', () {
    test('the credit account is the average, however it is spelled', () {
      for (final String title in <String>[
        'Credit-Sammelkonto',
        'credit-sammelkonto',
        'CREDIT-SAMMELKONTO',
        'Credit Sammelkonto',
        '  Credit  -  Sammelkonto  ',
        'Credit–Sammelkonto',
        'Credit‑Sammelkonto',
      ]) {
        expect(classifyQisRow(title), QisRowKind.average, reason: title);
      }
    });

    test('the thesis admission is recognised, however it is spelled', () {
      for (final String title in <String>[
        'Zulassung zur Abschlussarbeit',
        'zulassung zur abschlussarbeit',
        'Zulassung  zur   Abschlussarbeit',
      ]) {
        expect(
          classifyQisRow(title),
          QisRowKind.thesisAdmission,
          reason: title,
        );
      }
    });

    test('anything else is an ordinary exam', () {
      for (final String title in <String>[
        'Analysis I',
        'Abschlussarbeit',
        'Zulassung zur Prüfung',
        'Credits',
        'Sammelkonto Sport',
      ]) {
        expect(classifyQisRow(title), QisRowKind.exam, reason: title);
      }
    });
  });

  group('the projection', () {
    test('takes the average from the credit account, unchanged', () {
      // Explicitly not recomputed: HIS-QIS owns this number, and an average
      // the app derived itself would disagree with the official transcript.
      final GradeProjection projection = GradeProjection.of(
        GradeReport(<GradeEntry>[
          _row('Analysis I', grade: const Grade.graded(1.7)),
          _row('Credit-Sammelkonto', grade: const Grade.graded(2.4)),
          _row('Programmierung', grade: const Grade.graded(3.3)),
        ]),
      );

      expect(projection.average, const Grade.graded(2.4));
      expect(projection.hasAverage, isTrue);
    });

    test(
      'finds the average even when its row is an inner tree node, not a leaf',
      () {
        // On HISinOne, C-Sammelkonto is itself an inner node (it has a
        // child row) — the parser must never drop it before the projection
        // gets to classify it.
        final GradeProjection projection = GradeProjection.of(
          GradeReport(<GradeEntry>[
            GradeEntry(
              examNumber: '',
              title: 'C-Sammelkonto',
              grade: const Grade.graded(2.1),
              status: ExamStatus.passed,
              statusText: 'BE',
              isLeaf: false,
            ),
            _row('Analysis I', grade: const Grade.graded(1.7)),
          ]),
        );

        expect(projection.average, const Grade.graded(2.1));
        expect(projection.hasAverage, isTrue);
      },
    );

    test('hides the thesis admission row', () {
      final GradeProjection projection = GradeProjection.of(
        GradeReport(<GradeEntry>[
          _row('Zulassung zur Abschlussarbeit'),
          _row('Analysis I', grade: const Grade.graded(1.0)),
        ]),
      );

      expect(projection.exams.map((GradeEntry e) => e.title), <String>[
        'Analysis I',
      ]);
    });

    test('keeps every other row, including unrecognised ones', () {
      // Dropping a row the app failed to understand would hide a result the
      // student is entitled to see.
      final GradeProjection projection = GradeProjection.of(
        GradeReport(<GradeEntry>[
          _row('Analysis I'),
          _row('Ein völlig neuer Zeilentyp'),
          _row('Credit-Sammelkonto', grade: const Grade.graded(2.0)),
          _row('Programmierung'),
        ]),
      );

      expect(projection.exams, hasLength(3));
      expect(projection.exams.map((GradeEntry e) => e.title), <String>[
        'Analysis I',
        'Ein völlig neuer Zeilentyp',
        'Programmierung',
      ]);
    });

    test('the exam order is the report order', () {
      final GradeProjection projection = GradeProjection.of(
        GradeReport(<GradeEntry>[
          _row('B'),
          _row('Credit-Sammelkonto'),
          _row('A'),
          _row('C'),
        ]),
      );
      expect(projection.exams.map((GradeEntry e) => e.title), <String>[
        'B',
        'A',
        'C',
      ]);
    });

    test('a report without a credit account has no average', () {
      final GradeProjection projection = GradeProjection.of(
        GradeReport(<GradeEntry>[_row('Analysis I')]),
      );
      expect(projection.average, isNull);
      expect(projection.hasAverage, isFalse);
    });

    test('an ungraded credit account is not shown as an average', () {
      final GradeProjection projection = GradeProjection.of(
        GradeReport(<GradeEntry>[_row('Credit-Sammelkonto')]),
      );
      expect(projection.hasAverage, isFalse);
    });

    test('a second credit account does not overwrite the first', () {
      final GradeProjection projection = GradeProjection.of(
        GradeReport(<GradeEntry>[
          _row('Credit-Sammelkonto', grade: const Grade.graded(2.0)),
          _row('Credit-Sammelkonto', grade: const Grade.graded(4.0)),
        ]),
      );
      expect(projection.average, const Grade.graded(2.0));
    });

    test('an empty report projects to nothing', () {
      final GradeProjection projection = GradeProjection.of(
        const GradeReport(<GradeEntry>[]),
      );
      expect(projection.exams, isEmpty);
      expect(projection.average, isNull);
    });
  });
}
