// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'dart:async' show unawaited;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import "package:campus_koethen/core/theme/app_icons.dart";

import '../../../core/content/content_block.dart';
import '../../../core/links/linkified_text.dart';
import '../../../core/locale/formatters.dart';
import '../../calendar/domain/calendar_entry.dart' show calendarDayOf;
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/content_blocks_view.dart';
import '../../../core/widgets/panel.dart';
import '../../../l10n/l10n.dart';
import '../../notifications/presentation/pre_permission_sheet.dart';
import '../application/event_ui_providers.dart';
import '../application/saved_events_controller.dart';
import '../domain/event_source_label.dart';
import '../domain/saved_event_snapshot.dart';
import '../domain/unified_event.dart';

/// One event, compact by default: date/time, source, title and the
/// merken/entmerken action are always visible; the description, if there is
/// one, opens on tap.
///
/// [content] carries the event post's real content blocks (only known for
/// [UnifiedEventKind.postEvent], via the matching `NewsArticle`) — everything
/// else, including a calendar event, falls back to [UnifiedEvent.description]
/// as plain text. Without either, the card never offers to expand: "ohne
/// Beschreibung gibt es weder Aktion noch vermeintlich aufklappbare Karte".
class EventCard extends ConsumerWidget {
  const EventCard({
    required this.event,
    this.content,
    this.isPast = false,
    this.isOrphaned = false,
    super.key,
  });

  final UnifiedEvent event;
  final List<ContentBlock>? content;
  final bool isPast;
  final bool isOrphaned;

  bool get _hasDescription =>
      (content != null && content!.isNotEmpty) ||
      (event.description != null && event.description!.trim().isNotEmpty);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AppColors colors = context.colors;
    final AppTypography type = context.type;
    final TextTheme text = Theme.of(context).textTheme;
    final String locale = Localizations.localeOf(context).languageCode;

    final bool expanded =
        _hasDescription &&
        ref.watch(
          eventExpansionProvider.select(
            (Set<String> refs) => refs.contains(event.eventRef),
          ),
        );
    // Only this event's own state, and only whether the list is still
    // loading. Watching the whole list rebuilt every visible card whenever
    // any event was saved, and answering from it was a linear scan of a list
    // that may hold five hundred entries.
    final bool saved = ref.watch(
      savedEventRefsProvider.select(
        (Set<String> refs) => refs.contains(event.eventRef),
      ),
    );
    final bool savedLoading = ref.watch(
      savedEventsControllerProvider.select(
        (AsyncValue<List<SavedEventSnapshot>> saved) => saved.isLoading,
      ),
    );

    void onToggle() {
      if (!_hasDescription) return;
      ref.read(eventExpansionProvider.notifier).toggle(event.eventRef);
    }

    Future<void> onSaveToggle() async {
      final SavedEventsController notifier = ref.read(
        savedEventsControllerProvider.notifier,
      );
      unawaited(HapticFeedback.selectionClick());
      if (saved) {
        await notifier.remove(event.eventRef);
        return;
      }
      final bool ok = await notifier.save(event);
      if (!ok) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.eventSaveLimitReachedMessage)),
          );
        }
        return;
      }
      // Bookmarking an event is the clearest possible statement of interest
      // in being reminded about it — and the moment where an explanation
      // costs nothing, because the reader is already thinking about this
      // event. Asks at most once; the event is saved either way.
      if (!context.mounted) return;
      await maybeOfferNotificationOptIn(context, ref);
    }

    return Semantics(
      toggled: _hasDescription ? expanded : null,
      container: true,
      child: Panel(
        padding: EdgeInsets.all(context.metrics.cardPadding),
        onTap: _hasDescription ? onToggle : null,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      _WhenAndSource(event: event, locale: locale, l10n: l10n),
                      const SizedBox(height: AppSpacing.xxs),
                      Semantics(
                        header: true,
                        // The strike-through mirrors the calendar screen, but
                        // it is never the only signal — the badge below spells
                        // the state out, per AGENTS.md §9.
                        child: Text(
                          event.title,
                          style: event.isCancelled
                              ? text.titleMedium?.copyWith(
                                  decoration: TextDecoration.lineThrough,
                                  color: colors.textSecondary,
                                )
                              : text.titleMedium,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                _SaveButton(
                  saved: saved,
                  loading: savedLoading,
                  onPressed: onSaveToggle,
                  l10n: l10n,
                ),
              ],
            ),
            if (isPast || isOrphaned || event.isCancelled) ...<Widget>[
              const SizedBox(height: AppSpacing.xs),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xxs,
                children: <Widget>[
                  if (event.isCancelled)
                    _Badge(
                      label: l10n.eventCancelledBadge,
                      icon: AppIcons.cancel_outlined,
                      colour: colors.error,
                    ),
                  if (isPast) _Badge(label: l10n.eventPastBadge),
                  if (isOrphaned)
                    _Badge(
                      label: l10n.eventOrphanedBadge,
                      icon: AppIcons.cloud_off_outlined,
                      colour: colors.error,
                    ),
                ],
              ),
            ],
            if (event.location != null &&
                event.location!.trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSpacing.xs),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(
                    AppIcons.place_outlined,
                    size: AppSizes.iconSmall,
                    color: colors.textSecondary,
                  ),
                  const SizedBox(width: AppSpacing.xxs),
                  Expanded(child: Text(event.location!, style: type.dataSmall)),
                ],
              ),
            ],
            if (_hasDescription) ...<Widget>[
              const SizedBox(height: AppSpacing.sm),
              _Description(
                content: content,
                description: event.description,
                expanded: expanded,
                onToggle: onToggle,
                l10n: l10n,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Date/time (or "Ganztägig") on the left, the unique source on the right.
class _WhenAndSource extends StatelessWidget {
  const _WhenAndSource({
    required this.event,
    required this.locale,
    required this.l10n,
  });

  final UnifiedEvent event;
  final String locale;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final AppTypography type = context.type;
    // EVT-1: "Ganztägig" on its own told the reader nothing about WHICH day,
    // and this list aggregates weeks of events. The date is read through
    // `calendarDayOf`, which for an all-day value keeps the UTC-midnight
    // encoding the worker chose precisely so no device zone can shift it —
    // `toLocal()` here would move the date a day west of UTC (EVT-1/CAL-8).
    final DateTime startDay = calendarDayOf(event.start, allDay: event.allDay);
    final DateTime? end = event.end;
    final DateTime? endDay = end == null
        ? null
        : calendarDayOf(end, allDay: event.allDay);

    final String when;
    if (event.allDay) {
      final String date = AppDateFormats.weekdayDate(startDay, locale);
      // EVT-2: a range, wherever the source gives one.
      when = endDay != null && endDay.isAfter(startDay)
          ? '$date – ${AppDateFormats.weekdayDate(endDay, locale)}, '
                '${l10n.todayAllDayLabel}'
          : '$date, ${l10n.todayAllDayLabel}';
    } else {
      final String startText = AppDateFormats.dateTime(event.start, locale);
      when = end == null
          ? startText
          : (endDay != null && endDay.isAfter(startDay)
                // Across midnight the end needs its own date, not just a time.
                ? '$startText – ${AppDateFormats.dateTime(end, locale)}'
                : '$startText – ${AppDateFormats.time(end, locale)}');
    }
    final String? source = event.sourceLabel;
    final String? displaySource = source == null
        ? null
        : eventSourceDisplayLabel(source, isChannel: event.channelSlug != null);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(child: Text(when, style: type.dataSmall)),
        if (source != null && source.trim().isNotEmpty) ...<Widget>[
          const SizedBox(width: AppSpacing.sm),
          Flexible(
            child: Semantics(
              label: l10n.eventSourceSemanticLabel(source),
              excludeSemantics: true,
              child: Text(
                displaySource!,
                textAlign: TextAlign.end,
                style: type.dataSmall,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.label, this.icon, this.colour});

  final String label;
  final IconData? icon;
  final Color? colour;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final Color effective = colour ?? colors.textSecondary;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        if (icon != null) ...<Widget>[
          Icon(icon, size: AppSizes.iconSmall, color: effective),
          const SizedBox(width: AppSpacing.xxs),
        ],
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: effective),
        ),
      ],
    );
  }
}

/// The merken/entmerken action — at least 48×48 dp, its own tooltip and
/// semantics, immediate visual state.
class _SaveButton extends StatelessWidget {
  const _SaveButton({
    required this.saved,
    required this.loading,
    required this.onPressed,
    required this.l10n,
  });

  final bool saved;
  final bool loading;
  final VoidCallback onPressed;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final String tooltip = saved ? l10n.eventSaveRemove : l10n.eventSaveAdd;
    return Semantics(
      toggled: saved,
      label: tooltip,
      excludeSemantics: true,
      child: IconButton(
        tooltip: tooltip,
        onPressed: loading ? null : onPressed,
        constraints: const BoxConstraints(
          minWidth: AppSizes.minTouchTarget,
          minHeight: AppSizes.minTouchTarget,
        ),
        isSelected: saved,
        icon: const Icon(AppIcons.bookmark_outlined),
        selectedIcon: const Icon(AppIcons.bookmark),
      ),
    );
  }
}

/// The description: the post's real content blocks, or a calendar event's
/// plain-text description — collapsed to nothing until expanded.
class _Description extends StatelessWidget {
  const _Description({
    required this.content,
    required this.description,
    required this.expanded,
    required this.onToggle,
    required this.l10n,
  });

  final List<ContentBlock>? content;
  final String? description;
  final bool expanded;
  final VoidCallback onToggle;
  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    if (!expanded) {
      return Align(
        alignment: AlignmentDirectional.centerStart,
        child: TextButton.icon(
          onPressed: onToggle,
          icon: const Icon(
            AppIcons.keyboard_arrow_down,
            size: AppSizes.iconSmall,
          ),
          label: Text(l10n.newsShowMore),
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
          ),
        ),
      );
    }

    // A calendar description is plain text, so links have to be found rather
    // than parsed from markup — same reason `LinkifiedText` exists for mail
    // bodies. It only ever activates the three schemes `SafeLinkLauncher`
    // allows; anything else stays inert but selectable text.
    final Widget body = content != null && content!.isNotEmpty
        ? ContentBlocksView(blocks: content!)
        : LinkifiedText(
            description!,
            style: Theme.of(context).textTheme.bodyMedium,
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        body,
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Padding(
            padding: const EdgeInsets.only(top: AppSpacing.xs),
            child: TextButton.icon(
              onPressed: onToggle,
              icon: const Icon(
                AppIcons.keyboard_arrow_up,
                size: AppSizes.iconSmall,
              ),
              label: Text(l10n.newsShowLess),
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
