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
  final options = await _settle(ref.watch(eventSourceOptionsProvider.future));
  final state = ref.watch(eventSourceFilterProvider);
  Set<String>? selected = options == null
      ? null
      : EventSourceFilterRules.effectiveSelection(
          available: options,
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
      if (c.channelSlug != null &&
          (selected == null || selected.contains(c.channelSlug)))
        c.slug: c,
  };
  final parts = splitCalendarWindow(
    window(catalogue),
    catalogue?.meta.maxRangeDays ?? 120,
  );
  final (posts, events) = await (
    _settle(_loadPosts(ref, locale, parts, selected?.join(','))),
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
      for (final c in bySlug.values) c.channelSlug!,
      for (final p in posts?.articles ?? <NewsArticle>[]) p.primaryChannel.slug,
    };
    selected = EventSourceFilterRules.reconcile(state, [
      for (final key in available) EventSourceOption(key: key, label: key),
    ]).selectedKeys;
  }
  final selectedPosts = [
    for (final p in posts?.articles ?? <NewsArticle>[])
      if (p.isEventPost && selected.contains(p.primaryChannel.slug)) p,
  ];
  final selectedEvents = [
    for (final e in events?.value ?? <PublicCalendarEvent>[])
      if (bySlug.containsKey(e.calendarSlug) &&
          selected.contains(bySlug[e.calendarSlug]!.channelSlug))
        e,
  ];
  final merged = mergeEventSources(
    postEvents: selectedPosts.map(postToUnifiedEvent).toList(),
    calendarEvents: [
      for (final e in selectedEvents)
        calendarToUnifiedEvent(
          e,
          channelSlug: bySlug[e.calendarSlug]!.channelSlug,
        ),
    ],
  );
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
        selectedPosts.where((p) => keptPosts.contains(p.slug)),
      ),
      ...publicCalendarEventsToCalendarEntries(
        selectedEvents.where((e) => keptEvents.contains(e.id)).toList(),
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
