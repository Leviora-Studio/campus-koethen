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

/// Whether [calendarEvent] is an exact duplicate of [postEvent] under the
/// contract's dedup rule: identical channel/calendar attribution, identical
/// all-day flag, and a minute-exact identical start. A calendar event with no
/// [UnifiedEvent.channelSlug] (unmapped to any channel) can never match —
/// callers should not even offer it to this check, but it is also guarded
/// here for safety.
bool isDuplicateCalendarEvent({
  required UnifiedEvent postEvent,
  required UnifiedEvent calendarEvent,
}) {
  if (calendarEvent.channelSlug == null) return false;
  if (postEvent.channelSlug != calendarEvent.channelSlug) return false;
  if (postEvent.allDay != calendarEvent.allDay) return false;
  return sameStartMinute(postEvent.start, calendarEvent.start);
}

/// Everything [isDuplicateCalendarEvent] compares, as one comparable string:
/// the all-day flag, the start truncated to the minute in UTC, and the channel
/// attribution. Two events are duplicates under the rule exactly when their
/// keys are equal — so a set of keys can answer what a nested loop answered.
///
/// `null` for an event with no channel attribution: the rule can never call
/// such an event a duplicate, in either direction. The channel comes last so a
/// slug containing the separator cannot be read as a different key.
String? _dedupKey(UnifiedEvent event) {
  final String? channel = event.channelSlug;
  if (channel == null) return null;
  final int startMinute = event.start.millisecondsSinceEpoch ~/ 60000;
  return '${event.allDay}|$startMinute|$channel';
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

/// The single reusable merge+dedup function for the event overview AND the
/// calendar (per contract, "eine einzige wiederverwendbare Funktion").
///
/// Every event post is kept as-is. A calendar event is kept unless an event
/// post exists with identical primaryChannel/calendar-channelSlug, identical
/// all-day flag and a minute-exact identical start — in which case the post
/// wins **completely**; fields are never mixed between the two.
///
/// A calendar event with no channel mapping is never suppressed. Two events
/// on the same day with a different start time, different channels or a
/// different all-day flag are never treated as duplicates.
List<UnifiedEvent> mergeEventSources({
  required List<UnifiedEvent> postEvents,
  required List<UnifiedEvent> calendarEvents,
}) {
  final List<UnifiedEvent> result = List<UnifiedEvent>.of(postEvents);
  final EventDedupIndex posts = EventDedupIndex(postEvents);
  for (final UnifiedEvent calendarEvent in calendarEvents) {
    if (!posts.hasCounterpartOf(calendarEvent)) result.add(calendarEvent);
  }
  return result;
}
