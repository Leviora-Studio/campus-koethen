// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:meta/meta.dart';

import 'grade.dart';
import 'grade_projection.dart';

/// Everything the grades screen draws, derived from one [GradeReport].
///
/// The projection separates the credit account and the administrative row from
/// the exam rows; [entries] narrows those down to the leaves the list shows and
/// puts them in display order.
@immutable
class GradesDisplay {
  const GradesDisplay({required this.projection, required this.entries});

  final GradeProjection projection;

  /// Leaf exam rows in display order — grouped by module where the report has
  /// one, date-sorted otherwise.
  final List<GradeEntry> entries;
}

/// Cache for [gradesForDisplay], keyed by the report instance itself.
///
/// The controller keeps the same [GradeReport] across every rebuild that does
/// not fetch (the sync spinner, a theme change, the popup menu opening, the
/// return to the tab), and deriving the display is the expensive part of the
/// screen: `GradeProjection.of` re-normalises and re-matches the title of every
/// row, and the ordering re-sorts them. The values belong to the report and
/// never change for a given instance, so this happens once per report rather
/// than once per build. A fresh sync creates a new instance, which gets its own
/// entry.
final Expando<GradesDisplay> _cache = Expando<GradesDisplay>('gradesDisplay');

/// The projection and the ordered leaf rows of [report].
GradesDisplay gradesForDisplay(GradeReport report) =>
    _cache[report] ??= _derive(report);

GradesDisplay _derive(GradeReport report) {
  final GradeProjection projection = GradeProjection.of(report);
  // The projection still classifies EVERY tree row (so a non-leaf
  // `C-Sammelkonto` average is still found); only the list of individual
  // results is narrowed to actual leaves here.
  return GradesDisplay(
    projection: projection,
    entries: orderGradesForDisplay(
      projection.exams.where((GradeEntry e) => e.isLeaf).toList(),
    ),
  );
}

/// Leaf exam rows, grouped under their parent tree node's title (HISinOne).
///
/// A report without a tree (legacy HIS-QIS, `module` is always null) falls back
/// to the flat, date-sorted list.
@visibleForTesting
List<GradeEntry> orderGradesForDisplay(List<GradeEntry> entries) {
  final bool hasModules = entries.any(
    (GradeEntry e) => e.module != null && e.module!.isNotEmpty,
  );
  if (!hasModules) return _sortedByDate(entries);

  final Map<String, List<GradeEntry>> byModule = <String, List<GradeEntry>>{};
  final List<String> moduleOrder = <String>[];
  final List<GradeEntry> ungrouped = <GradeEntry>[];
  for (final GradeEntry e in entries) {
    final String? m = e.module;
    if (m == null || m.isEmpty) {
      ungrouped.add(e);
      continue;
    }
    if (!byModule.containsKey(m)) {
      byModule[m] = <GradeEntry>[];
      moduleOrder.add(m);
    }
    byModule[m]!.add(e);
  }
  return <GradeEntry>[
    for (final String m in moduleOrder) ...byModule[m]!,
    ...ungrouped,
  ];
}

List<GradeEntry> _sortedByDate(List<GradeEntry> entries) {
  return List<GradeEntry>.of(entries)..sort((GradeEntry a, GradeEntry b) {
    final DateTime? da = a.examDate;
    final DateTime? db = b.examDate;
    if (da == null && db == null) return 0;
    if (da == null) return 1; // undated rows sink to the end, never lost
    if (db == null) return -1;
    return db.compareTo(da); // newest first
  });
}
