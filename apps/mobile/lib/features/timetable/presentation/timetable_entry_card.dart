// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:flutter/material.dart';
import "package:campus_koethen/core/theme/app_icons.dart";

import '../../../core/locale/formatters.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../l10n/l10n.dart';
import '../../calendar/application/calendar_merge.dart';
import '../../calendar/presentation/calendar_entry_sheet.dart';
import '../data/timetable_models.dart';

/// Localised label of an entry status. Foreign content is never translated —
/// this is an app-owned label, so it is bilingual.
String timetableStatusLabel(
  AppLocalizations l10n,
  TimetableEntryStatus status,
) => switch (status) {
  TimetableEntryStatus.regular => l10n.timetableStatusRegular,
  TimetableEntryStatus.changed => l10n.timetableStatusChanged,
  TimetableEntryStatus.cancelled => l10n.timetableStatusCancelled,
  TimetableEntryStatus.unknown => l10n.timetableStatusUnknown,
};

/// Icon of an entry status. Every state is carried by icon **and** text, never
/// by colour alone.
IconData timetableStatusIcon(TimetableEntryStatus status) => switch (status) {
  TimetableEntryStatus.regular => AppIcons.event_available_outlined,
  TimetableEntryStatus.changed => AppIcons.edit_calendar_outlined,
  TimetableEntryStatus.cancelled => AppIcons.event_busy_outlined,
  TimetableEntryStatus.unknown => AppIcons.help_outline,
};

/// Localised label of an entry type.
String timetableTypeLabel(AppLocalizations l10n, TimetableEntryType type) =>
    switch (type) {
      TimetableEntryType.regularTeaching => l10n.timetableTypeRegular,
      TimetableEntryType.additional => l10n.timetableTypeAdditional,
      TimetableEntryType.unknown => l10n.timetableTypeUnknown,
    };

/// One appointment of the day agenda.
///
/// Subject, teacher, room and group names come from the source system and are
/// rendered verbatim in every language. Cancelled, changed and unknown states
/// always show an icon *and* a text label and carry a screen reader label.
///
/// Tapping opens the same detail sheet the calendar uses — one slot has one
/// detail view, whichever screen it was tapped on.
class TimetableEntryCard extends StatelessWidget {
  const TimetableEntryCard({required this.entry, super.key});

  final TimetableEntry entry;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AppColors colors = context.colors;
    final TextTheme text = Theme.of(context).textTheme;
    final String locale = Localizations.localeOf(context).languageCode;

    final String timeRange = l10n.timetableTimeRange(
      AppDateFormats.time(entry.start, locale),
      AppDateFormats.time(entry.end, locale),
    );
    final String title = entry.displayTitle ?? l10n.timetableUntitledEntry;
    final bool cancelled = entry.status == TimetableEntryStatus.cancelled;

    // Room and lecturer belong in the label, not just on the card.
    // `excludeSemantics` removes everything below from the tree, so whatever
    // the label leaves out simply does not exist for a screen reader — and the
    // room is the single most useful thing on this card to someone crossing
    // the campus to get there.
    final String details = <String>[
      timetableTypeLabel(l10n, entry.type),
      if (entry.rooms.isNotEmpty)
        '${l10n.timetableRoomsLabel}: '
            '${entry.rooms.map((TimetableRoom r) => r.label).join(', ')}',
      if (entry.teachers.isNotEmpty)
        '${l10n.timetableTeachersLabel}: '
            '${entry.teachers.map((TimetableTeacher t) => t.label).join(', ')}',
      if (entry.note != null && entry.note!.trim().isNotEmpty) entry.note!,
    ].join(', ');

    return Semantics(
      container: true,
      label:
          '${l10n.timetableEntrySemanticLabel(timeRange, title, timetableStatusLabel(l10n, entry.status))}, '
          '$details',
      excludeSemantics: true,
      button: true,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => showCalendarEntrySheet(
            context,
            timetableEntryToCalendarEntry(entry),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  timeRange,
                  style: text.titleSmall?.copyWith(color: colors.primary),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  title,
                  style: text.titleMedium?.copyWith(
                    decoration: cancelled ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  timetableTypeLabel(l10n, entry.type),
                  style: text.bodySmall?.copyWith(color: colors.textSecondary),
                ),
                if (entry.status.needsAttention) ...<Widget>[
                  const SizedBox(height: AppSpacing.sm),
                  _StatusRow(status: entry.status),
                ],
                if (entry.teachers.isNotEmpty) ...<Widget>[
                  const SizedBox(height: AppSpacing.sm),
                  _DetailRow(
                    icon: AppIcons.person_outline,
                    label: l10n.timetableTeachersLabel,
                    values: entry.teachers
                        .map((TimetableTeacher teacher) => teacher.label)
                        .toList(growable: false),
                  ),
                ],
                if (entry.rooms.isNotEmpty) ...<Widget>[
                  const SizedBox(height: AppSpacing.xs),
                  _DetailRow(
                    icon: AppIcons.meeting_room_outlined,
                    label: l10n.timetableRoomsLabel,
                    values: entry.rooms
                        .map((TimetableRoom room) => room.label)
                        .toList(growable: false),
                  ),
                ],
                if (entry.note != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.sm),
                  Text(entry.note!, style: text.bodySmall),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({required this.status});

  final TimetableEntryStatus status;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final TextTheme text = Theme.of(context).textTheme;
    // Cancelled is the only negative state; changed and unknown are neutral
    // hints. Both always carry an icon and a text label.
    final Color accent = status == TimetableEntryStatus.cancelled
        ? colors.error
        : colors.textPrimary;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(timetableStatusIcon(status), size: AppSizes.icon, color: accent),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            timetableStatusLabel(context.l10n, status),
            style: text.titleSmall?.copyWith(color: accent),
          ),
        ),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.label,
    required this.values,
  });

  final IconData icon;
  final String label;
  final List<String> values;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final TextTheme text = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Icon(icon, size: AppSizes.icon, color: colors.textSecondary),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                label,
                style: text.labelMedium?.copyWith(color: colors.textSecondary),
              ),
              for (final String value in values)
                Text(value, style: text.bodyMedium),
            ],
          ),
        ),
      ],
    );
  }
}
