// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:campus_koethen/features/calendar/application/calendar_merge.dart';
import 'package:campus_koethen/features/calendar/domain/calendar_entry.dart';
import 'package:campus_koethen/features/events/domain/saved_event_snapshot.dart';
import 'package:campus_koethen/features/events/domain/unified_event.dart';
import 'package:flutter_test/flutter_test.dart';

SavedEventSnapshot _saved({
  String eventRef = 'calendar:key1',
  UnifiedEventKind kind = UnifiedEventKind.calendarEvent,
  DateTime? start,
  bool allDay = false,
  String? channelSlug,
  String? calendarSlug = 'stura-termine',
  String? sourceLabel,
  String title = 'Gemerktes Event',
}) => SavedEventSnapshot(
  eventRef: eventRef,
  kind: kind,
  title: title,
  start: start ?? DateTime.utc(2026, 8, 10, 18),
  savedAt: DateTime.utc(2026, 8, 1),
  allDay: allDay,
  channelSlug: channelSlug,
  calendarSlug: calendarSlug,
  sourceLabel: sourceLabel,
);

CalendarEntry _livePublicEntry({
  String calendarSlug = 'stura-termine',
  String eventId = 'key1',
  DateTime? start,
  bool allDay = false,
  String title = 'Live-Termin',
}) => CalendarEntry(
  id: 'publicCalendar:$calendarSlug:$eventId',
  source: CalendarSource.publicCalendar,
  title: title,
  start: start ?? DateTime.utc(2026, 8, 10, 18),
  allDay: allDay,
  calendarSlug: calendarSlug,
);

void main() {
  group('savedEventEntriesForCalendar', () {
    test('a saved calendar snapshot already live is not duplicated', () {
      final List<CalendarEntry> out = savedEventEntriesForCalendar(
        saved: <SavedEventSnapshot>[_saved(eventRef: 'calendar:key1')],
        liveEntries: <CalendarEntry>[_livePublicEntry(eventId: 'key1')],
        channelSlugByCalendarSlug: const <String, String?>{},
      );
      expect(out, isEmpty);
    });

    test(
      'a saved calendar event stays unprefixed despite its linked channel',
      () {
        final List<CalendarEntry> out = savedEventEntriesForCalendar(
          saved: <SavedEventSnapshot>[
            _saved(
              eventRef: 'calendar:key1',
              channelSlug: 'campus-events',
              sourceLabel: 'Campus Events',
            ),
          ],
          liveEntries: const <CalendarEntry>[],
          channelSlugByCalendarSlug: const <String, String?>{},
        );
        expect(out, hasLength(1));
        expect(out.single.source, CalendarSource.savedEvents);
        expect(out.single.id, 'savedEvent:calendar:key1');
        expect(out.single.sourceLabel, 'Campus Events');
      },
    );

    test('a saved post event keeps the @ channel marker in the calendar', () {
      final List<CalendarEntry> out = savedEventEntriesForCalendar(
        saved: <SavedEventSnapshot>[
          _saved(
            eventRef: 'post:summer-party',
            kind: UnifiedEventKind.postEvent,
            channelSlug: 'campus-events',
            calendarSlug: null,
            sourceLabel: 'Campus Events',
          ),
        ],
        liveEntries: const <CalendarEntry>[],
        channelSlugByCalendarSlug: const <String, String?>{},
      );

      expect(out.single.sourceLabel, '@Campus Events');
    });

    test('a saved calendar-only source label stays unchanged', () {
      final List<CalendarEntry> out = savedEventEntriesForCalendar(
        saved: <SavedEventSnapshot>[
          _saved(eventRef: 'calendar:key2', sourceLabel: 'StuRa-Termine'),
        ],
        liveEntries: const <CalendarEntry>[],
        channelSlugByCalendarSlug: const <String, String?>{},
      );
      expect(out.single.sourceLabel, 'StuRa-Termine');
    });

    test('a saved post event duplicating a live calendar entry by channel and '
        'minute-exact start is suppressed', () {
      final DateTime start = DateTime.utc(2026, 8, 10, 18, 0);
      final List<CalendarEntry> out = savedEventEntriesForCalendar(
        saved: <SavedEventSnapshot>[
          _saved(
            eventRef: 'post:x',
            kind: UnifiedEventKind.postEvent,
            channelSlug: 'campus-events',
            calendarSlug: null,
            start: start,
          ),
        ],
        liveEntries: <CalendarEntry>[
          _livePublicEntry(
            calendarSlug: 'stura-termine',
            eventId: 'key2',
            start: start,
          ),
        ],
        channelSlugByCalendarSlug: const <String, String?>{
          'stura-termine': 'campus-events',
        },
      );
      expect(out, isEmpty);
    });

    test('a saved post event with a different channel is kept alongside a live '
        'entry at the same time', () {
      final DateTime start = DateTime.utc(2026, 8, 10, 18, 0);
      final List<CalendarEntry> out = savedEventEntriesForCalendar(
        saved: <SavedEventSnapshot>[
          _saved(
            eventRef: 'post:x',
            kind: UnifiedEventKind.postEvent,
            channelSlug: 'other-channel',
            calendarSlug: null,
            start: start,
          ),
        ],
        liveEntries: <CalendarEntry>[
          _livePublicEntry(
            calendarSlug: 'stura-termine',
            eventId: 'key2',
            start: start,
          ),
        ],
        channelSlugByCalendarSlug: const <String, String?>{
          'stura-termine': 'campus-events',
        },
      );
      expect(out, hasLength(1));
    });
  });
}
