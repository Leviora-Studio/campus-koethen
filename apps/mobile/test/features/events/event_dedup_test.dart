// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:campus_koethen/features/events/domain/event_dedup.dart';
import 'package:campus_koethen/features/events/domain/unified_event.dart';
import 'package:flutter_test/flutter_test.dart';

UnifiedEvent post({
  String ref = 'post:a',
  DateTime? start,
  DateTime? end,
  bool allDay = false,
  String channel = 'campus-events',
  String title = 'Postveranstaltung',
}) => UnifiedEvent(
  eventRef: ref,
  kind: UnifiedEventKind.postEvent,
  title: title,
  start: start ?? DateTime.utc(2026, 8, 10, 18),
  end: end,
  allDay: allDay,
  channelSlug: channel,
  postSlug: ref.split(':').last,
);

UnifiedEvent calendarEvent({
  String ref = 'calendar:key1',
  DateTime? start,
  DateTime? end,
  bool allDay = false,
  String? channel = 'campus-events',
  String calendarSlug = 'stura-termine',
  String title = 'Kalenderveranstaltung',
}) => UnifiedEvent(
  eventRef: ref,
  kind: UnifiedEventKind.calendarEvent,
  title: title,
  start: start ?? DateTime.utc(2026, 8, 10, 18),
  end: end,
  allDay: allDay,
  channelSlug: channel,
  calendarSlug: calendarSlug,
  calendarEventId: ref.split(':').last,
);

void main() {
  group('isDuplicateCalendarEvent', () {
    test('exact time-bound match is a duplicate', () {
      final UnifiedEvent p = post(start: DateTime.utc(2026, 8, 10, 18, 0));
      final UnifiedEvent c = calendarEvent(
        start: DateTime.utc(2026, 8, 10, 18, 0),
      );
      expect(isDuplicateCalendarEvent(postEvent: p, calendarEvent: c), isTrue);
    });

    test('exact all-day match is a duplicate', () {
      final UnifiedEvent p = post(
        start: DateTime.utc(2026, 8, 10),
        allDay: true,
      );
      final UnifiedEvent c = calendarEvent(
        start: DateTime.utc(2026, 8, 10),
        allDay: true,
      );
      expect(isDuplicateCalendarEvent(postEvent: p, calendarEvent: c), isTrue);
    });

    test('same day but a different start time is not a duplicate', () {
      final UnifiedEvent p = post(start: DateTime.utc(2026, 8, 10, 18, 0));
      final UnifiedEvent c = calendarEvent(
        start: DateTime.utc(2026, 8, 10, 19, 0),
      );
      expect(isDuplicateCalendarEvent(postEvent: p, calendarEvent: c), isFalse);
    });

    test('same start time but different channels is not a duplicate', () {
      final UnifiedEvent p = post(
        start: DateTime.utc(2026, 8, 10, 18, 0),
        channel: 'campus-news',
      );
      final UnifiedEvent c = calendarEvent(
        start: DateTime.utc(2026, 8, 10, 18, 0),
        channel: 'campus-events',
      );
      expect(isDuplicateCalendarEvent(postEvent: p, calendarEvent: c), isFalse);
    });

    test('a calendar without a channel mapping is never suppressed', () {
      final UnifiedEvent p = post(start: DateTime.utc(2026, 8, 10, 18, 0));
      final UnifiedEvent c = calendarEvent(
        start: DateTime.utc(2026, 8, 10, 18, 0),
        channel: null,
      );
      expect(isDuplicateCalendarEvent(postEvent: p, calendarEvent: c), isFalse);
    });

    test('a different all-day flag is not a duplicate', () {
      final UnifiedEvent p = post(
        start: DateTime.utc(2026, 8, 10),
        allDay: true,
      );
      final UnifiedEvent c = calendarEvent(
        start: DateTime.utc(2026, 8, 10),
        allDay: false,
      );
      expect(isDuplicateCalendarEvent(postEvent: p, calendarEvent: c), isFalse);
    });

    test('seconds and below never matter — still minute-exact', () {
      final UnifiedEvent p = post(start: DateTime.utc(2026, 8, 10, 18, 0, 0));
      final UnifiedEvent c = calendarEvent(
        start: DateTime.utc(2026, 8, 10, 18, 0, 59),
      );
      expect(isDuplicateCalendarEvent(postEvent: p, calendarEvent: c), isTrue);
    });
  });

  group('mergeEventSources', () {
    test('a matching calendar event is suppressed and the post wins whole', () {
      final UnifiedEvent p = post(title: 'Vom Post');
      final UnifiedEvent c = calendarEvent(title: 'Vom Kalender');
      final List<UnifiedEvent> merged = mergeEventSources(
        postEvents: <UnifiedEvent>[p],
        calendarEvents: <UnifiedEvent>[c],
      );
      expect(merged, hasLength(1));
      expect(merged.single.title, 'Vom Post');
      expect(merged.single.kind, UnifiedEventKind.postEvent);
    });

    test('a non-matching calendar event stays, both entries visible', () {
      final UnifiedEvent p = post(start: DateTime.utc(2026, 8, 10, 18));
      final UnifiedEvent c = calendarEvent(start: DateTime.utc(2026, 8, 11, 9));
      final List<UnifiedEvent> merged = mergeEventSources(
        postEvents: <UnifiedEvent>[p],
        calendarEvents: <UnifiedEvent>[c],
      );
      expect(merged, hasLength(2));
    });

    test('every post event is always kept, regardless of calendars', () {
      final UnifiedEvent p1 = post(ref: 'post:a');
      final UnifiedEvent p2 = post(
        ref: 'post:b',
        start: DateTime.utc(2026, 8, 11),
      );
      final List<UnifiedEvent> merged = mergeEventSources(
        postEvents: <UnifiedEvent>[p1, p2],
        calendarEvents: const <UnifiedEvent>[],
      );
      expect(merged, hasLength(2));
    });
  });

  group('EventDedupIndex', () {
    test('agrees with the pairwise rule on every combination', () {
      final List<UnifiedEvent> posts = <UnifiedEvent>[
        post(ref: 'post:a'),
        post(ref: 'post:b', start: DateTime.utc(2026, 8, 10, 18, 30)),
        post(ref: 'post:c', allDay: true, start: DateTime.utc(2026, 8, 11)),
        post(ref: 'post:d', channel: 'mensa'),
      ];
      final List<UnifiedEvent> calendars = <UnifiedEvent>[
        calendarEvent(ref: 'calendar:1'),
        calendarEvent(
          ref: 'calendar:2',
          start: DateTime.utc(2026, 8, 10, 18, 30, 44),
        ),
        calendarEvent(
          ref: 'calendar:3',
          allDay: true,
          start: DateTime.utc(2026, 8, 11),
        ),
        calendarEvent(ref: 'calendar:4', channel: null),
        calendarEvent(ref: 'calendar:5', channel: 'mensa'),
        calendarEvent(ref: 'calendar:6', start: DateTime.utc(2026, 9, 1)),
      ];

      final EventDedupIndex index = EventDedupIndex(posts);
      for (final UnifiedEvent c in calendars) {
        final bool byScan = posts.any(
          (UnifiedEvent p) =>
              isDuplicateCalendarEvent(postEvent: p, calendarEvent: c),
        );
        expect(
          index.hasCounterpartOf(c),
          byScan,
          reason: '${c.eventRef} must be judged exactly as the rule judges it',
        );
      }
    });

    test('works in the other direction too, the calendar merge uses', () {
      // The calendar indexes its live entries and asks about a saved post.
      final List<UnifiedEvent> live = <UnifiedEvent>[
        calendarEvent(ref: 'calendar:1'),
        calendarEvent(ref: 'calendar:2', channel: null),
      ];
      final EventDedupIndex index = EventDedupIndex(live);

      expect(index.hasCounterpartOf(post()), isTrue);
      expect(index.hasCounterpartOf(post(channel: 'mensa')), isFalse);
      expect(
        index.hasCounterpartOf(post(start: DateTime.utc(2026, 8, 10, 19))),
        isFalse,
      );
    });

    test('an event without a channel is never a counterpart', () {
      final EventDedupIndex index = EventDedupIndex(<UnifiedEvent>[
        calendarEvent(channel: null),
      ]);
      expect(index.hasCounterpartOf(calendarEvent(channel: null)), isFalse);
    });
  });
}
