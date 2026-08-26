// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:flutter/material.dart';
import "package:campus_koethen/core/theme/app_icons.dart";

import '../../../core/locale/formatters.dart';
import '../../../l10n/l10n.dart';
import '../domain/grade.dart';
import 'grade_messages.dart';

/// An icon + colour for a status, so it is never distinguished by colour alone.
({IconData icon, Color color}) _statusVisual(
  BuildContext context,
  ExamStatus s,
) {
  final ColorScheme scheme = Theme.of(context).colorScheme;
  return switch (s) {
    ExamStatus.passed => (
      icon: AppIcons.check_circle_outline,
      color: scheme.primary,
    ),
    ExamStatus.failed => (icon: AppIcons.cancel_outlined, color: scheme.error),
    ExamStatus.present => (
      icon: AppIcons.schedule_outlined,
      color: scheme.tertiary,
    ),
    ExamStatus.unknown => (
      icon: AppIcons.help_outline,
      color: scheme.onSurfaceVariant,
    ),
  };
}

/// One exam row in the grades list.
class GradeTile extends StatelessWidget {
  const GradeTile({required this.entry, required this.onTap, super.key});

  final GradeEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final String locale = Localizations.localeOf(context).languageCode;
    final TextTheme text = Theme.of(context).textTheme;
    final ({IconData icon, Color color}) visual = _statusVisual(
      context,
      entry.status,
    );

    final String subtitle = <String>[
      statusLabel(l10n, entry),
      if (entry.examDate != null)
        AppDateFormats.longDate(entry.examDate!, locale),
    ].join(' · ');

    return Semantics(
      button: true,
      // `excludeSemantics` was missing, so the custom label and the ListTile's
      // own nodes were both in the tree and the row was read twice. The label
      // also has to be complete now that it is the only one: date and attempt
      // are part of what tells two exam entries apart.
      excludeSemantics: true,
      label: <String>[
        entry.title,
        statusLabel(l10n, entry),
        gradeText(l10n, locale, entry.grade),
        if (entry.examDate != null)
          AppDateFormats.longDate(entry.examDate!, locale),
      ].join(', '),
      child: ListTile(
        leading: Icon(visual.icon, color: visual.color),
        title: Text(
          entry.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: text.bodyLarge,
        ),
        subtitle: Text(subtitle, style: text.bodySmall),
        // The width grows with the text size. Fixed at 96 dp, a long status
        // like "Bestanden (unbenotet)" was ellipsised away at exactly the
        // scale where it was hardest to read anyway.
        trailing: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: MediaQuery.textScalerOf(context).scale(_trailingWidth),
          ),
          child: Text(
            gradeText(l10n, locale, entry.grade),
            textAlign: TextAlign.end,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: text.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: entry.grade.isGraded ? visual.color : null,
            ),
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}

/// Width of the grade column at the reader's default text size.
const double _trailingWidth = 96;
