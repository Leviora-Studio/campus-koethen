// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:meta/meta.dart';

import 'grade.dart';

/// What a row of the QIS Notenspiegel actually is.
///
/// HIS-QIS mixes three different things into one table: real exam results, a
/// running credit account that already carries the average, and an
/// administrative admission row. They need different treatment, so they are
/// classified once, here, instead of being matched against strings in the UI.
enum QisRowKind {
  /// The "Credit-Sammelkonto" row. Its grade **is** the average — the app
  /// shows that value and never recomputes one of its own.
  average,

  /// "Zulassung zur Abschlussarbeit". An administrative state, not a result;
  /// it is not shown.
  thesisAdmission,

  /// An ordinary exam row.
  exam,
}

final RegExp _dashPattern = RegExp(r'[‐-―−-]');
final RegExp _whitespacePattern = RegExp(r'\s+');

/// Normalises a row title for matching.
///
/// Upper and lower case, runs of whitespace and the various dashes HIS uses
/// interchangeably (hyphen, non-breaking hyphen, en dash) all collapse, so
/// "Credit-Sammelkonto", "credit sammelkonto" and "Credit – Sammelkonto" are
/// the same row. Nothing else is touched: this decides classification only,
/// never what is displayed.
String normaliseQisTitle(String title) => title
    .toLowerCase()
    .replaceAll(_dashPattern, ' ')
    .replaceAll(_whitespacePattern, ' ')
    .trim();

/// Matches both the legacy "Credit-Sammelkonto" row and the HISinOne
/// "C-Sammelkonto" row — same meaning, different portal wording.
final RegExp _averageRowPattern = RegExp(r'^c(redit)? sammelkonto$');

/// Classifies one row by its title.
QisRowKind classifyQisRow(String title) {
  final String normalised = normaliseQisTitle(title);
  if (_averageRowPattern.hasMatch(normalised) ||
      normalised.contains('credit sammelkonto')) {
    return QisRowKind.average;
  }
  if (normalised.contains('zulassung zur abschlussarbeit')) {
    return QisRowKind.thesisAdmission;
  }
  return QisRowKind.exam;
}

/// What the grades screen shows.
///
/// Derived from the raw report; the encrypted cache keeps the untouched
/// original, so a later version can change this projection without another
/// round trip to HIS-QIS.
@immutable
class GradeProjection {
  const GradeProjection({required this.average, required this.exams});

  /// The value HIS-QIS itself keeps in the credit account, or `null` when the
  /// report has no such row. Never computed here.
  final Grade? average;

  /// Every ordinary exam row, in the order the report listed them.
  final List<GradeEntry> exams;

  bool get hasAverage => average != null && !average!.isEmpty;

  /// Builds the projection.
  ///
  /// Only the two known administrative rows are treated specially. Anything
  /// unrecognised stays an exam — dropping a row the app failed to understand
  /// would hide a result the student is entitled to see.
  factory GradeProjection.of(GradeReport report) {
    Grade? average;
    final List<GradeEntry> exams = <GradeEntry>[];
    for (final GradeEntry entry in report.entries) {
      switch (classifyQisRow(entry.title)) {
        case QisRowKind.average:
          // The first one wins: a second credit account would be a parsing
          // accident, not a second average.
          average ??= entry.grade;
        case QisRowKind.thesisAdmission:
          break;
        case QisRowKind.exam:
          exams.add(entry);
      }
    }
    return GradeProjection(
      average: average,
      exams: List<GradeEntry>.unmodifiable(exams),
    );
  }
}
