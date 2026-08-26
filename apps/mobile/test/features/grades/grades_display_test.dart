// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:campus_koethen/features/grades/domain/grade.dart';
import 'package:campus_koethen/features/grades/domain/grades_display.dart';
import 'package:flutter_test/flutter_test.dart';

GradeEntry _entry({
  required String title,
  DateTime? examDate,
  String? module,
  bool isLeaf = true,
}) => GradeEntry(
  examNumber: title,
  title: title,
  grade: const Grade.graded(2),
  status: ExamStatus.passed,
  statusText: 'bestanden',
  examDate: examDate,
  module: module,
  isLeaf: isLeaf,
);

void main() {
  group('gradesForDisplay', () {
    test('derives the projection and the ordered leaf rows once per report', () {
      final GradeReport report = GradeReport(<GradeEntry>[
        _entry(title: 'Credit-Sammelkonto'),
        _entry(title: 'Analysis', examDate: DateTime(2026, 2, 10)),
        _entry(title: 'Physik', examDate: DateTime(2026, 7, 1)),
      ]);

      final GradesDisplay first = gradesForDisplay(report);
      final GradesDisplay second = gradesForDisplay(report);

      // Same report, same instance: neither the classification of every row nor
      // the sort runs a second time.
      expect(identical(first, second), isTrue);
      expect(identical(first.entries, second.entries), isTrue);
      expect(identical(first.projection, second.projection), isTrue);
    });

    test('a fresh report is derived again', () {
      final List<GradeEntry> entries = <GradeEntry>[
        _entry(title: 'Analysis', examDate: DateTime(2026, 2, 10)),
      ];
      final GradesDisplay first = gradesForDisplay(GradeReport(entries));
      final GradesDisplay second = gradesForDisplay(GradeReport(entries));

      expect(identical(first, second), isFalse);
      expect(first.entries.single.title, 'Analysis');
      expect(second.entries.single.title, 'Analysis');
    });

    test('keeps the average out of the list and drops non-leaf rows', () {
      final GradeReport report = GradeReport(<GradeEntry>[
        _entry(title: 'C-Sammelkonto', isLeaf: false),
        _entry(title: 'Zulassung zur Abschlussarbeit'),
        _entry(title: 'Modul Mathematik', isLeaf: false),
        _entry(title: 'Analysis', examDate: DateTime(2026, 2, 10)),
      ]);

      final GradesDisplay display = gradesForDisplay(report);

      expect(display.projection.average, isNotNull);
      expect(display.entries.map((GradeEntry e) => e.title), <String>[
        'Analysis',
      ]);
    });
  });

  group('orderGradesForDisplay', () {
    test('without modules: newest first, undated last', () {
      final GradeEntry undated = _entry(title: 'Ohne Datum');
      final GradeEntry older = _entry(
        title: 'Aelter',
        examDate: DateTime(2025, 3, 1),
      );
      final GradeEntry newer = _entry(
        title: 'Neuer',
        examDate: DateTime(2026, 3, 1),
      );

      expect(
        orderGradesForDisplay(<GradeEntry>[
          undated,
          older,
          newer,
        ]).map((GradeEntry e) => e.title),
        <String>['Neuer', 'Aelter', 'Ohne Datum'],
      );
    });

    test('with modules: grouped in first-seen order, ungrouped last', () {
      final List<GradeEntry> ordered = orderGradesForDisplay(<GradeEntry>[
        _entry(title: 'A1', module: 'A'),
        _entry(title: 'B1', module: 'B'),
        _entry(title: 'lose'),
        _entry(title: 'A2', module: 'A'),
      ]);

      expect(ordered.map((GradeEntry e) => e.title), <String>[
        'A1',
        'A2',
        'B1',
        'lose',
      ]);
    });
  });
}
