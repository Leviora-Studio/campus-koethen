// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/locale/locale_providers.dart';
import '../../../core/network/api_meta.dart';
import '../../../core/network/loaded.dart';
import '../../events/application/event_providers.dart';
import '../../events/application/event_source_filter.dart';
import '../../events/data/event_posts_repository.dart';
import '../../events/domain/event_dedup.dart';
import '../../events/domain/unified_event.dart';
import '../../news/data/news_models.dart';
import '../../timetable/application/timetable_week.dart';
import '../data/public_calendars_repository.dart';
import '../domain/calendar_entry.dart';
import '../domain/public_calendar.dart';
import 'calendar_merge.dart';
import 'calendar_providers.dart';
import 'public_calendar_providers.dart';

/// The selected channels' posts and appointments, including partial/offline provenance.
final calendarEventMonthEntriesProvider =
    FutureProvider.family<Loaded<List<CalendarEntry>>, DateTime>(
      (ref, anchor) => ref.watch(
        _monthEntriesProvider(DateTime(anchor.year, anchor.month)).future,
      ),
      retry: (_, _) => null,
    );
void invalidateCalendarEventMonth(WidgetRef ref, DateTime month) {
  ref.invalidate(_monthEntriesProvider(DateTime(month.year, month.month)));
}

final _monthEntriesProvider =
    FutureProvider.family<Loaded<List<CalendarEntry>>, DateTime>((ref, anchor) {
      final weeks = monthWeekStarts(anchor);
      return _loadEventEntries(
        ref,
        window: (_) => CalendarDateWindow(
          from: weeks.first,
          to: TimetableWeek.shift(weeks.last, TimetableWeek.lengthInDays),
        ),
      );
    }, retry: (_, _) => null);
final calendarEventListEntriesProvider =
    FutureProvider.family<Loaded<List<CalendarEntry>>, DateTime>(
      (ref, today) =>
          ref.watch(_listEntriesProvider(calendarDayKey(today)).future),
      retry: (_, _) => null,
    );
final _listEntriesProvider =
    FutureProvider.family<Loaded<List<CalendarEntry>>, DateTime>(
      (ref, today) => _loadEventEntries(
        ref,
        window: (catalogue) =>
            calendarListWindow(today, catalogue?.meta.from, catalogue?.meta.to),
      ),
      retry: (_, _) => null,
    );

Future<Loaded<List<CalendarEntry>>> _loadEventEntries(
  Ref ref, {
  required CalendarDateWindow Function(Loaded<List<PublicCalendar>>?) window,
}) async {
  final locale = ref.watch(localeCodeProvider);
  final location = ref.watch(eventLocationFilterProvider);
  final options = await _settle(ref.watch(eventSourceOptionsProvider.future));
  final state = ref.watch(eventSourceFilterProvider);
  Set<String>? selected = options == null
      ? null
      : EventSourceFilterRules.effectiveSelection(
          available: eventOptionsAtLocation(options, location),
          selected: state.selectedKeys,
        );
  if (selected?.isEmpty ?? false) {
    return const Loaded(value: <CalendarEntry>[], meta: ApiMeta.empty);
  }
  final catalogue = await _settle(
    ref.watch(publicCalendarsCatalogProvider.future),
  );
  final bySlug = <String, PublicCalendar>{
    for (final c in catalogue?.value ?? <PublicCalendar>[])
      if (selected == null || selected.contains(c.filterSourceKey)) c.slug: c,
  };
  final parts = splitCalendarWindow(
    window(catalogue),
    catalogue?.meta.maxRangeDays ?? 120,
  );
  final selectedChannels = selected
      ?.where((key) => !key.startsWith('calendar:'))
      .toSet();
  final allChannels = options
      ?.where((option) => !option.key.startsWith('calendar:'))
      .length;
  final channelQuery =
      selectedChannels != null &&
          selectedChannels.isNotEmpty &&
          (selectedChannels.length == allChannels ||
              selectedChannels.length > 25)
      ? null
      : selectedChannels?.join(',');
  final (posts, events) = await (
    selectedChannels?.isEmpty == true
        ? Future.value(
            const EventPostsResult(
              articles: [],
              isTruncated: false,
              from: null,
              to: null,
            ),
          )
        : _settle(_loadPosts(ref, locale, parts, channelQuery)),
    bySlug.isEmpty
        ? Future<Loaded<List<PublicCalendarEvent>>?>.value(
            catalogue == null
                ? null
                : const Loaded(
                    value: <PublicCalendarEvent>[],
                    meta: ApiMeta.empty,
                  ),
          )
        : _settle(
            _loadCalendarEvents(
              ref,
              locale,
              bySlug.keys.toList(),
              parts,
              catalogue?.meta.maxCalendars ?? 1,
            ),
          ),
  ).wait;
  if (posts == null && events == null) {
    throw StateError('Neither event source could be loaded');
  }
  if (selected == null) {
    // A channel-catalogue failure must not hide independent source successes or
    // overwrite persisted opt-outs with an incomplete temporary catalogue.
    final available = <String>{
      for (final c in bySlug.values) c.filterSourceKey,
      for (final p in posts?.articles ?? <NewsArticle>[]) ...[
        p.primaryChannel.slug,
        ...p.channels.map((channel) => channel.slug),
      ],
    };
    selected = EventSourceFilterRules.reconcile(state, [
      for (final key in available) EventSourceOption(key: key, label: key),
    ]).selectedKeys;
  }
  final eventPosts = (posts?.articles ?? <NewsArticle>[]).where(
    (post) => post.isEventPost,
  );
  final calendarEvents = (events?.value ?? <PublicCalendarEvent>[]).where(
    (event) => bySlug.containsKey(event.calendarSlug),
  );
  final merged = selectAndMergeEvents([
    ...eventPosts.map(postToUnifiedEvent),
    for (final event in calendarEvents)
      calendarToUnifiedEvent(
        event,
        channelSlug: bySlug[event.calendarSlug]!.channelSlug,
      ),
  ], selected);
  final keptPosts = {
    for (final e in merged)
      if (e.postSlug != null) e.postSlug!,
  };
  final keptEvents = {
    for (final e in merged)
      if (e.calendarEventId != null) e.calendarEventId!,
  };
  return Loaded(
    value: [
      ...eventPostsToCalendarEntries(
        eventPosts.where((p) => keptPosts.contains(p.slug)),
      ),
      ...publicCalendarEventsToCalendarEntries(
        calendarEvents.where((e) => keptEvents.contains(e.id)).toList(),
        bySlug,
      ),
    ],
    fromCache:
        (catalogue?.fromCache ?? false) ||
        (posts?.fromCache ?? false) ||
        (events?.fromCache ?? false),
    meta: ApiMeta(
      truncated:
          (posts?.isTruncated ?? false) || (events?.meta.truncated ?? false),
      dataStale:
          options == null ||
          posts == null ||
          events == null ||
          (catalogue?.meta.dataStale ?? false) ||
          events.meta.dataStale,
    ),
  );
}

Future<T?> _settle<T>(Future<T> future) async {
  try {
    return await future;
  } catch (_) {
    return null;
  }
}

/// Split incomplete windows rather than silently discarding page 11 onward.
Future<EventPostsResult> _loadPosts(
  Ref ref,
  String locale,
  List<CalendarDateWindow> parts,
  String? channels,
) async {
  final repository = ref.watch(eventPostsRepositoryProvider);
  int remainingSplits = 16;
  Future<List<EventPostsResult>> load(CalendarDateWindow part) async {
    final response = await repository.fetchAllEventPosts(
      locale: locale,
      channelsParameter: channels,
      from: _isoDate(part.from),
      to: _isoDate(part.to),
    );
    if (response.isTruncated &&
        !response.fromCache &&
        part.from.isBefore(part.to) &&
        remainingSplits-- > 0) {
      final days =
          DateTime.utc(part.to.year, part.to.month, part.to.day)
              .difference(
                DateTime.utc(part.from.year, part.from.month, part.from.day),
              )
              .inDays +
          1;
      final halves = await Future.wait(
        splitCalendarWindow(part, (days / 2).ceil()).map(load),
      );
      return halves.expand((v) => v).toList();
    }
    return [response];
  }

  final results = (await Future.wait(
    parts.map(load),
  )).expand((v) => v).toList();
  final bySlug = {
    for (final result in results)
      for (final article in result.articles) article.slug: article,
  };
  return EventPostsResult(
    articles: bySlug.values.toList(),
    isTruncated: results.any((r) => r.isTruncated),
    from: results.firstOrNull?.from,
    to: results.lastOrNull?.to,
    fromCache: results.any((r) => r.fromCache),
  );
}

Future<Loaded<List<PublicCalendarEvent>>> _loadCalendarEvents(
  Ref ref,
  String locale,
  List<String> slugs,
  List<CalendarDateWindow> parts,
  int maxCalendars,
) async {
  final repository = ref.watch(publicCalendarsRepositoryProvider);
  int remainingSplits = 16;
  Future<Loaded<List<PublicCalendarEvent>>> load(
    CalendarDateWindow part,
  ) async {
    final response = await repository.fetchEvents(
      locale: locale,
      slugs: slugs,
      from: _isoDate(part.from),
      to: _isoDate(part.to),
      maxCalendars: maxCalendars,
    );
    if (!response.meta.truncated ||
        response.fromCache ||
        !part.from.isBefore(part.to) ||
        remainingSplits-- <= 0) {
      return response;
    }
    final days =
        DateTime.utc(part.to.year, part.to.month, part.to.day)
            .difference(
              DateTime.utc(part.from.year, part.from.month, part.from.day),
            )
            .inDays +
        1;
    return combineCalendarEventLoads(
      await Future.wait(splitCalendarWindow(part, (days / 2).ceil()).map(load)),
    );
  }

  return combineCalendarEventLoads(await Future.wait(parts.map(load)));
}

String _isoDate(DateTime day) => day.toIso8601String().substring(0, 10);
