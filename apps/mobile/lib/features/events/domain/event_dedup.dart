// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:meta/meta.dart';

import 'unified_event.dart';

/// Whether two start instants fall in the same minute, in UTC.
///
/// "minutengenau identischem Start-Instant": seconds and below never matter,
/// but the calendar day and hour must match exactly — this is an exact-time
/// comparison, never a same-day one.
bool sameStartMinute(DateTime a, DateTime b) =>
    a.millisecondsSinceEpoch ~/ 60000 == b.millisecondsSinceEpoch ~/ 60000;

/// Duplicates have the same channel, title, full UTC period and all-day flag.
bool isDuplicateCalendarEvent({
  required UnifiedEvent postEvent,
  required UnifiedEvent calendarEvent,
}) {
  final String? key = _dedupKey(calendarEvent);
  return key != null && key == _dedupKey(postEvent);
}

String? _dedupKey(UnifiedEvent event) {
  final String? channel = event.channelSlug;
  if (channel == null) return null;
  final String title = event.title.trim().replaceAll(RegExp(r'\s+'), ' ');
  return '$channel|${event.allDay}|${event.start.toUtc().microsecondsSinceEpoch}|${(event.end ?? event.start).toUtc().microsecondsSinceEpoch}|$title';
}

/// [isDuplicateCalendarEvent] as a lookup instead of a scan.
///
/// Both callers of the rule used to ask it once per pair: the event overview
/// checked every calendar event against every event post, and the calendar
/// checked every saved snapshot against every live entry. With the contract's
/// 10×50 ceiling on the post side alone that is a lot of comparisons, each
/// building two fresh [DateTime]s.
///
/// The rule itself is unchanged — this only states it once as a key and then
/// compares keys. It is symmetric on purpose: the overview indexes the posts
/// and asks about a calendar event, the calendar indexes the live entries and
/// asks about a saved post.
@immutable
class EventDedupIndex {
  EventDedupIndex(Iterable<UnifiedEvent> events)
    : _keys = <String>{
        for (final UnifiedEvent event in events)
          if (_dedupKey(event) case final String key) key,
      };

  final Set<String> _keys;

  /// Whether an indexed event is [isDuplicateCalendarEvent]-identical to
  /// [event] — the same answer `others.any(...)` gave.
  bool hasCounterpartOf(UnifiedEvent event) {
    final String? key = _dedupKey(event);
    return key != null && _keys.contains(key);
  }
}

/// Editorial appointment > event post > Google occurrence; keep whole entries.
List<UnifiedEvent> mergeEventSources({
  required List<UnifiedEvent> postEvents,
  required List<UnifiedEvent> calendarEvents,
}) {
  final List<UnifiedEvent> editorial = calendarEvents
      .where((e) => e.isEditorial)
      .toList();
  final EventDedupIndex appointments = EventDedupIndex(editorial);
  final List<UnifiedEvent> posts = postEvents
      .where((e) => !appointments.hasCounterpartOf(e))
      .toList();
  final EventDedupIndex preferred = EventDedupIndex([...editorial, ...posts]);
  return [
    ...posts,
    ...editorial,
    ...calendarEvents.where(
      (e) => !e.isEditorial && !preferred.hasCounterpartOf(e),
    ),
  ];
}
