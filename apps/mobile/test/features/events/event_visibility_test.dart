// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:campus_koethen/features/events/domain/event_visibility.dart';
import 'package:campus_koethen/features/events/domain/unified_event.dart';
import 'package:flutter_test/flutter_test.dart';

UnifiedEvent timed({
  String ref = 'post:a',
  required DateTime start,
  DateTime? end,
  bool allDay = false,
}) => UnifiedEvent(
  eventRef: ref,
  kind: UnifiedEventKind.postEvent,
  title: 'Event',
  start: start,
  end: end,
  allDay: allDay,
);

void main() {
  group('isEventVisibleInOverview — timed event with an end', () {
    test('a running long event stays visible', () {
      final DateTime now = DateTime(2026, 8, 20, 12);
      final UnifiedEvent event = timed(
        start: DateTime(2026, 8, 18, 9),
        end: DateTime(2026, 8, 22, 18),
      );
      expect(isEventVisibleInOverview(event, now: now), isTrue);
    });

    test('an event ending in one minute is still visible', () {
      final DateTime now = DateTime(2026, 8, 20, 12);
      final UnifiedEvent event = timed(
        start: DateTime(2026, 8, 20, 11),
        end: now.add(const Duration(minutes: 1)),
      );
      expect(isEventVisibleInOverview(event, now: now), isTrue);
      expect(hiddenAtBoundary(event), now.add(const Duration(minutes: 1)));
    });

    test('an event that ended one minute ago is hidden', () {
      final DateTime now = DateTime(2026, 8, 20, 12);
      final UnifiedEvent event = timed(
        start: DateTime(2026, 8, 20, 10),
        end: now.subtract(const Duration(minutes: 1)),
      );
      expect(isEventVisibleInOverview(event, now: now), isFalse);
    });

    test('disappears exactly at eventEnd, minute-exact (<=, not <)', () {
      final DateTime end = DateTime(2026, 8, 20, 12, 30);
      final UnifiedEvent event = timed(
        start: DateTime(2026, 8, 20, 10),
        end: end,
      );
      expect(isEventVisibleInOverview(event, now: end), isFalse);
      expect(
        isEventVisibleInOverview(
          event,
          now: end.subtract(const Duration(minutes: 1)),
        ),
        isTrue,
      );
    });
  });

  group('isEventVisibleInOverview — timed event without an end', () {
    test(
      'a post without an end stays visible today (no duration invented)',
      () {
        final DateTime now = DateTime(2026, 8, 20, 22, 30);
        final UnifiedEvent event = timed(start: DateTime(2026, 8, 20, 9));
        expect(isEventVisibleInOverview(event, now: now), isTrue);
        expect(hiddenAtBoundary(event), DateTime(2026, 8, 21));
      },
    );

    test(
      'a post without an end is hidden the next day, after local midnight',
      () {
        final UnifiedEvent event = timed(start: DateTime(2026, 8, 19, 9));
        final DateTime now = DateTime(2026, 8, 20, 0, 1); // yesterday's event
        expect(isEventVisibleInOverview(event, now: now), isFalse);
      },
    );

    test('exactly at the local midnight boundary it is already hidden', () {
      final UnifiedEvent event = timed(start: DateTime(2026, 8, 20, 9));
      expect(
        isEventVisibleInOverview(event, now: DateTime(2026, 8, 21)),
        isFalse,
      );
      expect(
        isEventVisibleInOverview(
          event,
          now: DateTime(2026, 8, 21).subtract(const Duration(minutes: 1)),
        ),
        isTrue,
      );
    });
  });

  group('isEventVisibleInOverview — all-day event', () {
    test(
      'a single-day all-day event disappears at the local midnight after',
      () {
        final UnifiedEvent event = timed(
          start: DateTime(2026, 8, 20),
          allDay: true,
        );
        expect(hiddenAtBoundary(event), DateTime(2026, 8, 21));
        expect(
          isEventVisibleInOverview(event, now: DateTime(2026, 8, 20, 23, 59)),
          isTrue,
        );
        expect(
          isEventVisibleInOverview(event, now: DateTime(2026, 8, 21)),
          isFalse,
        );
      },
    );

    test('a multi-day all-day event disappears at midnight after its exclusive '
        'last day, staying visible on every day it already covers', () {
      // end is EXCLUSIVE, per the calendar's own day-boundary convention:
      // a 3-day event 20th-22nd is encoded start=20th, end=23rd.
      final UnifiedEvent event = timed(
        start: DateTime(2026, 8, 20),
        end: DateTime(2026, 8, 23),
        allDay: true,
      );
      expect(hiddenAtBoundary(event), DateTime(2026, 8, 23));
      expect(
        isEventVisibleInOverview(event, now: DateTime(2026, 8, 20)),
        isTrue,
      );
      expect(
        isEventVisibleInOverview(event, now: DateTime(2026, 8, 22, 23, 59)),
        isTrue,
        reason: 'already running, still visible',
      );
      expect(
        isEventVisibleInOverview(event, now: DateTime(2026, 8, 23)),
        isFalse,
      );
    });
  });

  group('visibleEventsInOverview', () {
    test('keeps only running/upcoming events', () {
      final DateTime now = DateTime(2026, 8, 20, 12);
      final UnifiedEvent past = timed(
        ref: 'post:past',
        start: DateTime(2026, 8, 19, 9),
        end: DateTime(2026, 8, 19, 10),
      );
      final UnifiedEvent running = timed(
        ref: 'post:running',
        start: DateTime(2026, 8, 20, 9),
        end: DateTime(2026, 8, 20, 14),
      );
      final List<UnifiedEvent> visible = visibleEventsInOverview(<UnifiedEvent>[
        past,
        running,
      ], now: now);
      expect(visible, hasLength(1));
      expect(visible.single.eventRef, 'post:running');
    });
  });

  group('nextVisibilityBoundary', () {
    test(
      'picks the earliest boundary strictly after now, ignoring past ones',
      () {
        final DateTime now = DateTime(2026, 8, 20, 12);
        final UnifiedEvent alreadyEnded = timed(
          ref: 'post:ended',
          start: DateTime(2026, 8, 19),
          end: DateTime(2026, 8, 19, 23),
        );
        final UnifiedEvent endsSoon = timed(
          ref: 'post:soon',
          start: DateTime(2026, 8, 20, 9),
          end: DateTime(2026, 8, 20, 12, 5),
        );
        final UnifiedEvent endsLater = timed(
          ref: 'post:later',
          start: DateTime(2026, 8, 20, 9),
          end: DateTime(2026, 8, 20, 18),
        );
        final DateTime? boundary = nextVisibilityBoundary(<UnifiedEvent>[
          alreadyEnded,
          endsSoon,
          endsLater,
        ], now: now);
        expect(boundary, DateTime(2026, 8, 20, 12, 5));
      },
    );

    test('returns null when nothing is scheduled to disappear', () {
      expect(
        nextVisibilityBoundary(const <UnifiedEvent>[], now: DateTime(2026)),
        isNull,
      );
    });
  });
}
