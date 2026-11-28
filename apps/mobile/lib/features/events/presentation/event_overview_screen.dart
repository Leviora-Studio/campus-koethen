// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import "package:campus_koethen/core/theme/app_icons.dart";

import '../../../app/app_modules.dart';
import '../../../core/content/content_block.dart';
import '../../../core/locale/formatters.dart';
import '../../calendar/application/calendar_event_providers.dart';
import '../../calendar/application/calendar_merge.dart';
import '../../calendar/domain/calendar_entry.dart';
import '../../calendar/domain/calendar_entry_details.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_metrics.dart';
import '../../../core/widgets/offline_notice.dart';
import '../../../core/widgets/screen_scaffold.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/status_banner.dart';
import '../../../l10n/l10n.dart';
import '../../news/data/news_models.dart';
import '../application/event_providers.dart';
import '../application/event_source_filter.dart';
import '../application/saved_events_controller.dart';
import '../domain/saved_event_snapshot.dart';
import '../domain/event_sort.dart';
import '../domain/event_visibility.dart';
import '../domain/saved_events_rules.dart';
import '../domain/unified_event.dart';
import 'event_card.dart';
import 'event_source_filter_sheet.dart';

/// The dedicated event view: an aggregated, deduplicated, source-filtered
/// list of running/upcoming events, with a "Meine gemerkten Events" toggle
/// into the saved list — built entirely on [eventOverviewProvider] and
/// [savedEventsControllerProvider].
class EventOverviewScreen extends ConsumerStatefulWidget {
  const EventOverviewScreen({super.key});

  @override
  ConsumerState<EventOverviewScreen> createState() =>
      _EventOverviewScreenState();
}

class _EventOverviewScreenState extends ConsumerState<EventOverviewScreen>
    with WidgetsBindingObserver {
  bool _showSaved = false;
  DateTime? _month;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    ref.read(eventOverviewClockProvider.notifier).handleLifecycleState(state);
  }

  Future<void> _refresh() async {
    ref.invalidate(eventPostsOverviewProvider);
    ref.invalidate(eventCalendarsOverviewProvider);
    ref.read(eventOverviewClockProvider.notifier).recomputeNow();
    await Future.wait(<Future<void>>[
      ref.read(eventPostsOverviewProvider.future),
      ref.read(eventCalendarsOverviewProvider.future),
    ]);
  }

  Future<void> _chooseMonth() async {
    final today = ref.read(eventsClockProvider).now().toLocal();
    final initialMonth = _month ?? today;
    int selectedMonth = initialMonth.month;
    int selectedYear = initialMonth.year;
    final month = await showDialog<DateTime>(
      context: context,
      builder: (BuildContext context) {
        final l10n = context.l10n;
        final material = MaterialLocalizations.of(context);
        final locale = Localizations.localeOf(context).languageCode;
        return AlertDialog(
          title: Text(l10n.eventBrowseMonth),
          scrollable: true,
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              DropdownButtonFormField<int>(
                initialValue: selectedMonth,
                isExpanded: true,
                decoration: InputDecoration(labelText: l10n.eventMonthField),
                items: <DropdownMenuItem<int>>[
                  for (int month = 1; month <= 12; month++)
                    DropdownMenuItem<int>(
                      value: month,
                      child: Text(
                        AppDateFormats.month(
                          DateTime(today.year, month),
                          locale,
                        ),
                      ),
                    ),
                ],
                onChanged: (int? value) {
                  if (value != null) selectedMonth = value;
                },
              ),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<int>(
                initialValue: selectedYear,
                isExpanded: true,
                decoration: InputDecoration(labelText: l10n.eventYearField),
                items: <DropdownMenuItem<int>>[
                  for (int year = 2020; year <= today.year + 3; year++)
                    DropdownMenuItem<int>(
                      value: year,
                      child: Text(material.formatYear(DateTime(year))),
                    ),
                ],
                onChanged: (int? value) {
                  if (value != null) selectedYear = value;
                },
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(material.cancelButtonLabel),
            ),
            FilledButton(
              onPressed: () => Navigator.of(
                context,
              ).pop(DateTime(selectedYear, selectedMonth)),
              child: Text(material.okButtonLabel),
            ),
          ],
        );
      },
    );
    if (month != null && mounted) {
      setState(() {
        _showSaved = false;
        _month = month;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final EventOverviewData data = ref.watch(eventOverviewProvider);
    final AsyncValue<List<SavedEventSnapshot>> savedAsync = ref.watch(
      savedEventsControllerProvider,
    );
    final int savedCount = savedAsync.value?.length ?? 0;

    final EventSourceFilterState filterState = ref.watch(
      eventSourceFilterProvider,
    );
    final Set<String> selectedKeys = EventSourceFilterRules.effectiveSelection(
      available: eventOptionsAtLocation(
        data.sourceOptions,
        ref.watch(eventLocationFilterProvider),
      ),
      selected: filterState.selectedKeys,
    );
    final bool filterActive =
        ref.watch(eventLocationFilterProvider) != null ||
        (data.sourceOptions.isNotEmpty &&
            selectedKeys.length < data.sourceOptions.length);

    return ScreenScaffold(
      eyebrow: ModuleCategory.campus.label(l10n),
      title: l10n.newsEventsTitle,
      actions: <Widget>[
        // The only way to refresh this screen used to be pull-to-refresh, and
        // a drag is not exposed as an action — so with TalkBack, VoiceOver or
        // switch control there was no way to reload at all. The timetable has
        // had this button all along.
        IconButton(
          tooltip: l10n.actionRefresh,
          onPressed: _month == null || _showSaved
              ? _refresh
              : () => invalidateCalendarEventMonth(ref, _month!),
          icon: const Icon(AppIcons.refresh),
        ),
        IconButton(
          tooltip: _showSaved
              ? l10n.eventOverviewSavedHideTooltip
              : l10n.eventOverviewSavedShowTooltip,
          isSelected: _showSaved,
          onPressed: () => setState(() => _showSaved = !_showSaved),
          icon: const Icon(AppIcons.bookmark),
        ),
        IconButton(
          tooltip: l10n.eventBrowseMonth,
          isSelected: !_showSaved && _month != null,
          onPressed: _chooseMonth,
          icon: const Icon(AppIcons.calendar_month),
        ),
        IconButton(
          tooltip: l10n.eventOverviewFilterTooltip,
          isSelected: filterActive,
          onPressed: () => showEventSourceFilterSheet(context),
          icon: const Icon(AppIcons.filter_alt_outlined),
          selectedIcon: const Icon(AppIcons.filter_alt),
        ),
      ],
      controls: _showSaved
          ? _SavedModeBar(
              count: savedCount,
              onShowAll: () => setState(() => _showSaved = false),
            )
          : _month == null
          ? null
          : Align(
              alignment: AlignmentDirectional.centerStart,
              child: Padding(
                padding: EdgeInsets.symmetric(
                  horizontal: context.metrics.screenPadding,
                ),
                child: InputChip(
                  label: Text(
                    AppDateFormats.monthAndYear(
                      _month!,
                      Localizations.localeOf(context).languageCode,
                    ),
                  ),
                  deleteButtonTooltipMessage: l10n.eventShowUpcoming,
                  onDeleted: () => setState(() => _month = null),
                ),
              ),
            ),
      body: _showSaved
          ? _SavedEventsBody(
              onShowAll: () => setState(() => _showSaved = false),
            )
          : _month != null
          ? _MonthEventsBody(month: _month!)
          : _OverviewBody(
              data: data,
              selectedKeys: selectedKeys,
              onRefresh: _refresh,
            ),
    );
  }
}

class _SavedModeBar extends StatelessWidget {
  const _SavedModeBar({required this.count, required this.onShowAll});

  final int count;
  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AppMetrics metrics = context.metrics;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        metrics.screenPadding,
        0,
        metrics.screenPadding,
        AppSpacing.sm,
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              l10n.eventOverviewSavedCountLabel(count),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          TextButton(
            onPressed: onShowAll,
            child: Text(l10n.eventShowAllAction),
          ),
        ],
      ),
    );
  }
}

/// The month view reads the same entries as the calendar grid.
class _MonthEventsBody extends ConsumerWidget {
  const _MonthEventsBody({required this.month});

  final DateTime month;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final provider = calendarEventMonthEntriesProvider(month);
    final l10n = context.l10n;
    return ref
        .watch(provider)
        .when(
          loading: () => const LoadingView(),
          error: (error, _) => ErrorView(
            failure: error,
            onRetry: () => invalidateCalendarEventMonth(ref, month),
          ),
          data: (loaded) {
            final entries = <String, CalendarEntry>{};
            final mapped = <UnifiedEvent>[];
            final lastDay = DateTime(month.year, month.month + 1, 0);
            for (final entry in loaded.value) {
              if (entry.day.isAfter(lastDay) || entry.lastDay.isBefore(month)) {
                continue;
              }
              final event = liveCalendarEntryAsEvent(entry);
              if (event == null) continue;
              entries[event.eventRef] = entry;
              mapped.add(event);
            }
            final events = sortedUnifiedEvents(mapped);
            final now = ref.watch(eventOverviewClockProvider);
            return ListView(
              padding: EdgeInsets.all(context.metrics.screenPadding),
              children: [
                if (loaded.fromCache) const OfflineNotice(),
                if (loaded.meta.truncated || loaded.meta.dataStale)
                  StatusBanner(
                    tone: StatusTone.info,
                    title: l10n.eventTruncatedWarningTitle,
                    message: l10n.eventTruncatedWarningMessage,
                  ),
                if (events.isEmpty)
                  EmptyView(
                    icon: AppIcons.event_outlined,
                    message: l10n.eventNoEventsInMonth,
                  ),
                for (final event in events)
                  Padding(
                    padding: EdgeInsets.only(bottom: context.metrics.cardGap),
                    child: EventCard(
                      key: ValueKey(event.eventRef),
                      event: event,
                      content: switch (entries[event.eventRef]?.details) {
                        PostEventDetails(:final article) => article.content,
                        _ => null,
                      },
                      isPast: !isEventVisibleInOverview(event, now: now),
                    ),
                  ),
              ],
            );
          },
        );
  }
}

/// The aggregated overview: notices, per-source resilience banners, the empty
/// states and the event list itself.
class _OverviewBody extends ConsumerWidget {
  const _OverviewBody({
    required this.data,
    required this.selectedKeys,
    required this.onRefresh,
  });

  final EventOverviewData data;
  final Set<String> selectedKeys;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AppMetrics metrics = context.metrics;

    if (data.isLoading && data.events.isEmpty && !data.hasTotalFailure) {
      return const LoadingView();
    }

    if (data.hasTotalFailure) {
      return ErrorView(
        onRetry: () {
          ref.invalidate(eventPostsOverviewProvider);
          ref.invalidate(eventCalendarsOverviewProvider);
        },
      );
    }

    final Map<String, NewsArticle> articlesBySlug = ref.watch(
      eventArticlesBySlugProvider,
    );

    final List<Widget> notices = <Widget>[
      if (data.postsFromCache)
        OfflineNotice(
          cachedAt: ref.watch(eventPostsOverviewProvider).value?.cachedAt,
        ),
      if (data.hasPostsError && !data.postsFromCache)
        StatusBanner(
          tone: StatusTone.warning,
          icon: AppIcons.sync_problem,
          title: l10n.eventPostsUnavailableWarning,
          action: TextButton(
            onPressed: () => ref.invalidate(eventPostsOverviewProvider),
            child: Text(l10n.actionRetry),
          ),
        ),
      if (data.hasCalendarError && !data.calendarsFromCache)
        StatusBanner(
          tone: StatusTone.warning,
          icon: AppIcons.sync_problem,
          title: l10n.eventCalendarsUnavailableWarning,
          action: TextButton(
            onPressed: () => ref.invalidate(eventCalendarsOverviewProvider),
            child: Text(l10n.actionRetry),
          ),
        ),
      if (data.isTruncated)
        StatusBanner(
          tone: StatusTone.info,
          title: l10n.eventTruncatedWarningTitle,
          message: l10n.eventTruncatedWarningMessage,
        ),
    ];

    if (data.events.isEmpty) {
      final Widget empty = selectedKeys.isEmpty && data.sourceOptions.isNotEmpty
          ? EmptyView(
              icon: AppIcons.filter_list_off,
              title: l10n.eventOverviewNoSourcesTitle,
              message: l10n.eventOverviewNoSourcesMessage,
              action: FilledButton.icon(
                onPressed: () => showEventSourceFilterSheet(context),
                icon: const Icon(AppIcons.filter_alt_outlined),
                label: Text(l10n.eventSourceFilterOpenAction),
              ),
            )
          : EmptyView(
              icon: AppIcons.event_outlined,
              title: l10n.eventOverviewEmptyTitle,
              message: l10n.eventOverviewEmptyMessage,
            );

      return RefreshIndicator(
        onRefresh: onRefresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: <Widget>[
            if (notices.isNotEmpty)
              SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(
                    metrics.screenPadding,
                    AppSpacing.md,
                    metrics.screenPadding,
                    0,
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: notices,
                  ),
                ),
              ),
            SliverFillRemaining(child: empty),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView.separated(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          metrics.screenPadding,
          AppSpacing.md,
          metrics.screenPadding,
          metrics.sectionGap,
        ),
        itemCount: notices.length + data.events.length,
        separatorBuilder: (BuildContext context, int index) =>
            SizedBox(height: metrics.cardGap),
        itemBuilder: (BuildContext context, int index) {
          if (index < notices.length) return notices[index];
          final UnifiedEvent event = data.events[index - notices.length];
          final NewsArticle? article = event.postSlug == null
              ? null
              : articlesBySlug[event.postSlug];
          return EventCard(
            key: ValueKey<String>(event.eventRef),
            event: event,
            content: article?.content,
          );
        },
      ),
    );
  }
}

/// "Meine gemerkten Events": upcoming/running first, past ones in their own
/// muted section, orphaned entries marked independently of "vergangen".
class _SavedEventsBody extends ConsumerWidget {
  const _SavedEventsBody({required this.onShowAll});

  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AppMetrics metrics = context.metrics;
    final AsyncValue<List<SavedEventSnapshot>> savedAsync = ref.watch(
      savedEventsControllerProvider,
    );

    // The snapshot itself carries everything the card needs offline. When the
    // live post happens to be loaded anyway, its content blocks are richer than
    // the snapshot's plain text, so prefer them — but never depend on them.
    final Map<String, NewsArticle> articlesBySlug = ref.watch(
      eventArticlesBySlugProvider,
    );
    List<ContentBlock>? contentFor(SavedEventSnapshot snapshot) {
      if (snapshot.kind != UnifiedEventKind.postEvent) return null;
      final String slug = snapshot.eventRef.startsWith('post:')
          ? snapshot.eventRef.substring('post:'.length)
          : snapshot.eventRef;
      return articlesBySlug[slug]?.content;
    }

    return switch (savedAsync) {
      AsyncLoading<List<SavedEventSnapshot>>() when !savedAsync.hasValue =>
        const LoadingView(),
      AsyncError<List<SavedEventSnapshot>>() => ErrorView(
        onRetry: () => ref.invalidate(savedEventsControllerProvider),
      ),
      _ => Builder(
        builder: (BuildContext context) {
          final List<SavedEventSnapshot> saved = savedAsync.requireValue;
          if (saved.isEmpty) {
            return EmptyView(
              icon: AppIcons.bookmark_outlined,
              title: l10n.eventSavedEmptyTitle,
              message: l10n.eventSavedEmptyMessage,
              action: FilledButton.icon(
                onPressed: onShowAll,
                icon: const Icon(AppIcons.event_outlined),
                label: Text(l10n.eventShowAllAction),
              ),
            );
          }

          final SavedEventsGroups groups = groupSavedEvents(
            saved,
            now: ref.watch(savedEventsClockProvider)(),
          );
          final int itemCount =
              groups.upcoming.length +
              (groups.past.isEmpty ? 0 : 1 + groups.past.length);

          return ListView.separated(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.fromLTRB(
              metrics.screenPadding,
              AppSpacing.md,
              metrics.screenPadding,
              metrics.sectionGap,
            ),
            itemCount: itemCount,
            separatorBuilder: (BuildContext context, int index) =>
                SizedBox(height: metrics.cardGap),
            itemBuilder: (BuildContext context, int index) {
              if (index < groups.upcoming.length) {
                final SavedEventSnapshot snapshot = groups.upcoming[index];
                return EventCard(
                  key: ValueKey<String>(snapshot.eventRef),
                  event: snapshot.toUnifiedEvent(),
                  content: contentFor(snapshot),
                  isOrphaned: snapshot.isOrphaned,
                );
              }
              final int afterUpcoming = index - groups.upcoming.length;
              if (afterUpcoming == 0) {
                return Semantics(
                  header: true,
                  child: Text(
                    l10n.eventSavedPastSectionTitle,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                );
              }
              final SavedEventSnapshot snapshot =
                  groups.past[afterUpcoming - 1];
              return EventCard(
                key: ValueKey<String>(snapshot.eventRef),
                event: snapshot.toUnifiedEvent(),
                content: contentFor(snapshot),
                isPast: true,
                isOrphaned: snapshot.isOrphaned,
              );
            },
          );
        },
      ),
    };
  }
}
