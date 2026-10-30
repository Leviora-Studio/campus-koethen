// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/locale/locale_providers.dart';
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

/// The calendar's "Events" source: everything the event overview offers, for
/// the channels selected in the one shared event-source filter — their event
/// posts and the events of their public calendars, deduplicated by the events
/// feature's own rule (a post supersedes the identical calendar event).
///
/// The calendar only differs from the overview in *when*: it shows the window
/// it is looking at, past days included, where the overview shows what is
/// running or still to come.

/// Event entries for the month around [anchor], already mapped to
/// source-neutral [CalendarEntry] values.
///
/// Keyed by an explicit anchor rather than reading the calendar screen's
/// focused day: the dashboard asks about *today* while the calendar screen may
/// be browsing another month, and a shared focus would make one of them wrong.
///
/// Any two days of the same month ask for the identical window, so the family
/// key is normalised to the first of the month before anything is requested.
/// Retrying stays switched off on both entries: a failure is surfaced to the
/// aggregator, which isolates it per source.
final calendarEventMonthEntriesProvider =
    FutureProvider.family<List<CalendarEntry>, DateTime>(
      (Ref ref, DateTime anchor) => ref.watch(
        _monthEntriesProvider(DateTime(anchor.year, anchor.month)).future,
      ),
      retry: (_, _) => null,
    );

final _monthEntriesProvider =
    FutureProvider.family<List<CalendarEntry>, DateTime>((
      Ref ref,
      DateTime anchor,
    ) {
      final List<DateTime> weeks = monthWeekStarts(anchor);
      return _loadEventEntries(
        ref,
        window: (_) => CalendarDateWindow(
          from: weeks.first,
          to: TimetableWeek.shift(weeks.last, TimetableWeek.lengthInDays),
        ),
      );
    }, retry: (_, _) => null);

/// Event entries for the full horizon advertised by the backend.
///
/// The outer provider normalises its key to today at local midnight. Rebuilds
/// during the same day therefore reuse the same backend responses, while the
/// next day naturally advances both inclusive bounds by one.
final calendarEventListEntriesProvider =
    FutureProvider.family<List<CalendarEntry>, DateTime>(
      (Ref ref, DateTime today) =>
          ref.watch(_listEntriesProvider(calendarDayKey(today)).future),
      retry: (_, _) => null,
    );

final _listEntriesProvider =
    FutureProvider.family<List<CalendarEntry>, DateTime>(
      (Ref ref, DateTime today) => _loadEventEntries(
        ref,
        window: (Loaded<List<PublicCalendar>>? catalogue) =>
            calendarListWindow(today, catalogue?.meta.from, catalogue?.meta.to),
      ),
      retry: (_, _) => null,
    );

/// Loads, filters and merges both halves of the source for one window.
///
/// The two halves are isolated from each other like the calendar's sources
/// are: event posts still show when the public calendars fail, and the other
/// way round. Only when neither could be had does the source report an error.
Future<List<CalendarEntry>> _loadEventEntries(
  Ref ref, {
  required CalendarDateWindow Function(Loaded<List<PublicCalendar>>? catalogue)
  window,
}) async {
  final String locale = ref.watch(localeCodeProvider);
  final List<EventSourceOption> options = await ref.watch(
    eventSourceOptionsProvider.future,
  );
  final Set<String> selected = EventSourceFilterRules.effectiveSelection(
    available: options,
    selected: ref.watch(eventSourceFilterProvider).selectedKeys,
  );
  if (selected.isEmpty) return const <CalendarEntry>[];

  Loaded<List<PublicCalendar>>? catalogue;
  try {
    catalogue = await ref.watch(publicCalendarsCatalogProvider.future);
  } catch (_) {
    catalogue = null; // The event posts can still be shown.
  }
  final List<PublicCalendar> calendars =
      catalogue?.value ?? const <PublicCalendar>[];
  final Map<String, PublicCalendar> bySlug = <String, PublicCalendar>{
    for (final PublicCalendar calendar in calendars)
      if (calendar.channelSlug case final String channel
          when selected.contains(channel))
        calendar.slug: calendar,
  };

  // Old backend versions do not advertise their request limit; they used
  // 120-day list requests, so keep that safe fallback during rollout. The
  // event-post endpoint shares the calendar's range limit.
  final List<CalendarDateWindow> parts = splitCalendarWindow(
    window(catalogue),
    catalogue?.meta.maxRangeDays ?? 120,
  );

  final (List<NewsArticle>? posts, List<PublicCalendarEvent>? events) = await (
    _settle(_loadPosts(ref, locale, parts)),
    bySlug.isEmpty
        ? Future<List<PublicCalendarEvent>?>.value(
            catalogue == null ? null : const <PublicCalendarEvent>[],
          )
        : _settle(
            _loadCalendarEvents(ref, locale, bySlug.keys.toList(), parts),
          ),
  ).wait;
  if (posts == null && events == null) {
    throw StateError(
      'Neither event posts nor public calendars could be loaded',
    );
  }

  final List<NewsArticle> selectedPosts = <NewsArticle>[
    for (final NewsArticle post in posts ?? const <NewsArticle>[])
      if (post.isEventPost && selected.contains(post.primaryChannel.slug)) post,
  ];
  final List<PublicCalendarEvent> calendarEvents = <PublicCalendarEvent>[
    for (final PublicCalendarEvent event
        in events ?? const <PublicCalendarEvent>[])
      if (bySlug.containsKey(event.calendarSlug)) event,
  ];

  final Set<String> keptCalendarEventIds = <String>{
    for (final UnifiedEvent event in mergeEventSources(
      postEvents: selectedPosts.map(postToUnifiedEvent).toList(),
      calendarEvents: <UnifiedEvent>[
        for (final PublicCalendarEvent event in calendarEvents)
          calendarToUnifiedEvent(
            event,
            channelSlug: bySlug[event.calendarSlug]!.channelSlug,
          ),
      ],
    ))
      if (event.calendarEventId case final String id) id,
  };

  return <CalendarEntry>[
    ...eventPostsToCalendarEntries(selectedPosts),
    ...publicCalendarEventsToCalendarEntries(
      calendarEvents
          .where((PublicCalendarEvent e) => keptCalendarEventIds.contains(e.id))
          .toList(),
      bySlug,
    ),
  ];
}

/// [future]'s value, or `null` when it failed.
Future<T?> _settle<T>(Future<T> future) async {
  try {
    return await future;
  } catch (_) {
    return null;
  }
}

/// Every event post overlapping [parts], each once even when it spans two.
Future<List<NewsArticle>> _loadPosts(
  Ref ref,
  String locale,
  List<CalendarDateWindow> parts,
) async {
  final EventPostsRepository repository = ref.watch(
    eventPostsRepositoryProvider,
  );
  final List<EventPostsResult> results = await Future.wait(
    parts.map(
      (CalendarDateWindow part) => repository.fetchAllEventPosts(
        locale: locale,
        from: _isoDate(part.from),
        to: _isoDate(part.to),
      ),
    ),
  );
  final Map<String, NewsArticle> bySlug = <String, NewsArticle>{
    for (final EventPostsResult result in results)
      for (final NewsArticle article in result.articles) article.slug: article,
  };
  return bySlug.values.toList(growable: false);
}

/// The events of [slugs] across [parts]. A part the server cut short is split
/// in half until every event fits.
Future<List<PublicCalendarEvent>> _loadCalendarEvents(
  Ref ref,
  String locale,
  List<String> slugs,
  List<CalendarDateWindow> parts,
) async {
  final PublicCalendarsRepository repository = ref.watch(
    publicCalendarsRepositoryProvider,
  );

  Future<List<PublicCalendarEvent>> load(CalendarDateWindow part) async {
    final Loaded<List<PublicCalendarEvent>> response = await repository
        .fetchEvents(
          locale: locale,
          slugs: slugs,
          from: _isoDate(part.from),
          to: _isoDate(part.to),
        );
    if (!response.meta.truncated) return response.value;
    if (!part.from.isBefore(part.to)) {
      throw StateError('Calendar event response remains truncated for one day');
    }
    final int days =
        DateTime.utc(part.to.year, part.to.month, part.to.day)
            .difference(
              DateTime.utc(part.from.year, part.from.month, part.from.day),
            )
            .inDays +
        1;
    final List<List<PublicCalendarEvent>> halves = await Future.wait(
      splitCalendarWindow(part, (days / 2).ceil()).map(load),
    );
    return halves.expand((chunk) => chunk).toList(growable: false);
  }

  final List<List<PublicCalendarEvent>> chunks = await Future.wait(
    parts.map(load),
  );
  final Map<String, PublicCalendarEvent> byId = <String, PublicCalendarEvent>{
    for (final List<PublicCalendarEvent> chunk in chunks)
      for (final PublicCalendarEvent event in chunk) event.id: event,
  };
  return byId.values.toList(growable: false);
}

/// The `YYYY-MM-DD` form of a calendar day.
String _isoDate(DateTime day) => day.toIso8601String().substring(0, 10);
