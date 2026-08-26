// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:flutter/material.dart';
import "package:campus_koethen/core/theme/app_icons.dart";

import '../../../core/locale/formatters.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../core/theme/app_typography.dart';
import '../../../l10n/l10n.dart';
import '../../timetable/application/timetable_week.dart';

/// A compact seven-day strip above the agenda.
///
/// Replaces the month grid as the primary way to move around: on a phone a
/// month grid costs most of the screen and answers a question ("which day?")
/// that a week strip answers in a fifth of the space.
///
/// The strip is swiped sideways to change week — one week per swipe, keeping
/// the selected weekday, arbitrarily far in either direction. The day content
/// below keeps its own day-at-a-time swipe; the two never meet, because a
/// gesture belongs to whichever of the two the finger started on.
///
/// It shows all seven days even when the week **view** is set to Monday to
/// Friday: this is the day picker, and a Saturday has to stay reachable.
///
/// ## Two states, two materials
///
/// *Selected* and *today* are different questions and are answered with
/// different ink. The day you are looking at is filled solid — it is structure,
/// so it is ink. Today wears the marker under it — it is live, so it is the
/// marker. When they coincide you get both, and neither state has to be
/// inferred from a shade. A day that has entries additionally carries a dot, so
/// "there is something here" survives in greyscale too.
class WeekStrip extends StatelessWidget {
  const WeekStrip({
    required this.selected,
    required this.today,
    required this.entryCounts,
    required this.onSelect,
    required this.eventDays,
    required this.onShiftWeeks,
    required this.onToday,
    super.key,
  });

  final DateTime selected;
  final DateTime today;

  /// Number of entries per day, used for the marker and the screen-reader
  /// description. Missing means zero.
  final Map<DateTime, int> entryCounts;

  final ValueChanged<DateTime> onSelect;

  /// Called with `+1`/`-1` when the strip is swiped.
  /// Every day that carries an entry, spanning entries included.
  final Set<DateTime> eventDays;

  final ValueChanged<int> onShiftWeeks;

  final VoidCallback onToday;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AppMetrics metrics = context.metrics;
    final String locale = Localizations.localeOf(context).languageCode;
    final DateTime start = TimetableWeek.startOf(selected);

    return Semantics(
      container: true,
      label: l10n.calendarWeekStripSemantic(
        AppDateFormats.weekdayDate(selected, locale),
      ),
      child: GestureDetector(
        // One week per swipe regardless of how far or how fast the finger
        // travelled: a calendar that jumped three weeks on a quick flick would
        // be impossible to aim.
        onHorizontalDragEnd: (DragEndDetails details) {
          final double velocity = details.primaryVelocity ?? 0;
          if (velocity == 0) return;
          onShiftWeeks(velocity < 0 ? 1 : -1);
        },
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            metrics.screenPadding - AppSpacing.xs,
            AppSpacing.xs,
            metrics.screenPadding - AppSpacing.xs,
            AppSpacing.sm,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      AppDateFormats.monthAndYear(selected, locale),
                      key: const Key('weekStripMonthLabel'),
                      style: Theme.of(context).textTheme.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.xs,
                      ),
                    ),
                    onPressed: onToday,
                    icon: const Icon(
                      AppIcons.today_outlined,
                      size: AppSizes.iconSmall,
                    ),
                    label: Text(l10n.calendarToday),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: l10n.calendarPreviousWeek,
                    onPressed: () => onShiftWeeks(-1),
                    icon: const Icon(AppIcons.chevron_left),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    tooltip: l10n.calendarNextWeek,
                    onPressed: () => onShiftWeeks(1),
                    icon: const Icon(AppIcons.chevron_right),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.xs),
              Row(
                children: <Widget>[
                  for (int i = 0; i < TimetableWeek.lengthInDays; i++)
                    Expanded(
                      child: _DayCell(
                        day: TimetableWeek.shift(start, i),
                        selected: selected,
                        today: today,
                        entryCount:
                            entryCounts[TimetableWeek.shift(start, i)] ?? 0,
                        hasEntry: eventDays.contains(
                          TimetableWeek.shift(start, i),
                        ),
                        onSelect: onSelect,
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.selected,
    required this.today,
    required this.entryCount,
    required this.hasEntry,
    required this.onSelect,
  });

  final DateTime day;
  final DateTime selected;
  final DateTime today;

  /// How many entries START on this day. Drives the spoken count.
  final int entryCount;

  /// Whether anything is on this day at all, a multi-day entry passing
  /// through included. Drives the dot.
  ///
  /// The two differ on purpose: a week-long entry begins once but occupies
  /// every day, and the strip used to leave the days after the first blank
  /// while the day list underneath happily showed the entry — the strip and
  /// the list contradicting each other about the same day.
  final bool hasEntry;

  final ValueChanged<DateTime> onSelect;

  bool get _isSelected => _sameDay(day, selected);
  bool get _isToday => _sameDay(day, today);

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AppColors colors = context.colors;
    final AppTypography type = context.type;
    final String locale = Localizations.localeOf(context).languageCode;

    final Color ink = _isSelected ? colors.surface : colors.textPrimary;
    final Color quiet = _isSelected ? colors.surface : colors.textSecondary;

    return Semantics(
      button: true,
      selected: _isSelected,
      label: AppDateFormats.weekdayDate(day, locale),
      value: entryCount > 0 ? l10n.calendarDayHasEntries(entryCount) : null,
      excludeSemantics: true,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.card),
        onTap: () => onSelect(day),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xxs),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: AppSizes.minTouchTarget,
                ),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                  decoration: BoxDecoration(
                    color: _isSelected ? colors.textPrimary : null,
                    borderRadius: BorderRadius.circular(AppRadius.card),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Text(
                        AppDateFormats.shortWeekday(day, locale),
                        style: type.dataSmall.copyWith(color: quiet),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        AppDateFormats.dayOfMonth(day, locale),
                        style: type.data.copyWith(
                          color: ink,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xxs),
                      // "There is something on this day", as a shape.
                      SizedBox(
                        height: AppSpacing.xs,
                        child: hasEntry
                            ? Container(
                                width: AppSpacing.xs,
                                height: AppSpacing.xs,
                                decoration: BoxDecoration(
                                  color: ink,
                                  shape: BoxShape.circle,
                                ),
                              )
                            : null,
                      ),
                    ],
                  ),
                ),
              ),
              // Today's marker sits under the cell rather than inside it, so a
              // day can be today *and* the one being read without the two
              // states having to share a background.
              const SizedBox(height: AppSpacing.xxs),
              SizedBox(
                width: double.infinity,
                height: AppSizes.beam,
                child: _isToday ? ColoredBox(color: colors.accent) : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
