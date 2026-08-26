// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'unified_event.dart';

/// Deterministic order for the merged current/running event list: start
/// ascending, all-day before timed within the same start/day, then title,
/// then [UnifiedEvent.eventRef] as a stable final tie-breaker.
int compareUnifiedEvents(UnifiedEvent a, UnifiedEvent b) {
  final int byStart = a.start.compareTo(b.start);
  if (byStart != 0) return byStart;

  final int byAllDay = (a.allDay == b.allDay)
      ? 0
      : (a.allDay ? -1 : 1); // all-day sorts first
  if (byAllDay != 0) return byAllDay;

  final int byTitle = a.title.compareTo(b.title);
  if (byTitle != 0) return byTitle;

  return a.eventRef.compareTo(b.eventRef);
}

/// Sorts a copy of [events] with [compareUnifiedEvents].
List<UnifiedEvent> sortedUnifiedEvents(List<UnifiedEvent> events) =>
    List<UnifiedEvent>.of(events)..sort(compareUnifiedEvents);
