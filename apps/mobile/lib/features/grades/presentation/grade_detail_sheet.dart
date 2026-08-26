// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:flutter/material.dart';

import '../../../core/locale/formatters.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/widgets/sheet_body.dart';
import '../../../l10n/l10n.dart';
import '../domain/grade.dart';
import 'grade_messages.dart';

/// Shows all fields of one exam row in a bottom sheet.
Future<void> showGradeDetailSheet(BuildContext context, GradeEntry entry) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (BuildContext context) => _GradeDetailSheet(entry: entry),
  );
}

class _GradeDetailSheet extends StatelessWidget {
  const _GradeDetailSheet({required this.entry});

  final GradeEntry entry;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).languageCode;
    final TextTheme text = Theme.of(context).textTheme;

    final List<({String label, String value})> rows =
        <({String label, String value})>[
          if (entry.module != null && entry.module!.isNotEmpty)
            (label: l10n.gradeFieldModule, value: entry.module!),
          (
            label: l10n.gradeFieldGrade,
            value: gradeText(l10n, locale, entry.grade),
          ),
          (label: l10n.gradeFieldStatus, value: statusLabel(l10n, entry)),
          if (entry.examDate != null)
            (
              label: l10n.gradeFieldDate,
              value: AppDateFormats.longDate(entry.examDate!, locale),
            ),
          if (entry.attempt != null)
            (label: l10n.gradeFieldAttempt, value: entry.attempt!),
          if (entry.examNumber.isNotEmpty)
            (label: l10n.gradeFieldExamNumber, value: entry.examNumber),
          if (entry.points != null)
            (label: l10n.gradeFieldPoints, value: entry.points!),
          if (entry.bonus != null)
            (label: l10n.gradeFieldBonus, value: entry.bonus!),
          if (entry.examiner != null && entry.examiner!.isNotEmpty)
            (label: l10n.gradeFieldExaminer, value: entry.examiner!),
          // Portal columns without a dedicated field — the portal's OWN header
          // text is shown verbatim as the label, never renamed or reinterpreted
          // (e.g. a HISinOne "Bonus"-looking column must stay "Bonus", never
          // "ECTS").
          for (final MapEntry<String, String> extra in entry.extras.entries)
            (label: extra.key, value: extra.value),
        ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        // A HISinOne entry can carry a dozen extra portal columns, and at a
        // large text size those ran past the bottom of the sheet with no way
        // to reach them. The sheet is already `isScrollControlled`, so this
        // costs nothing in the ordinary case.
        child: SingleChildScrollView(
          child: SheetBody(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  entry.title.isEmpty ? l10n.gradeDetailTitle : entry.title,
                  style: text.titleLarge,
                ),
                const SizedBox(height: AppSpacing.md),
                for (final ({String label, String value}) row in rows)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        SizedBox(
                          width: MediaQuery.textScalerOf(
                            context,
                          ).scale(_labelWidth),
                          child: Text(
                            row.label,
                            style: text.bodyMedium?.copyWith(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(row.value, style: text.bodyMedium),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Width of the field-name column at the reader's default text size.
const double _labelWidth = 132;
