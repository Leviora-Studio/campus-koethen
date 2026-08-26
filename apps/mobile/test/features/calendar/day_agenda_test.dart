// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:campus_koethen/features/calendar/application/calendar_providers.dart';
import 'package:campus_koethen/features/calendar/domain/calendar_entry.dart';
import 'package:flutter_test/flutter_test.dart';

DateTime _at(int hour, [int minute = 0]) => DateTime(2026, 5, 12, hour, minute);

CalendarEntry _entry(
  String id, {
  required int from,
  required int to,
  bool allDay = false,
  CalendarSource source = CalendarSource.timetable,
}) => CalendarEntry(
  id: id,
  source: source,
  title: id,
  start: _at(from),
  end: _at(to),
  allDay: allDay,
);

final CalendarData _healthy = CalendarData(
  entries: <CalendarEntry>[],
  enabledSources: <CalendarSource>{},
  timetableLoading: false,
  hasTimetableError: false,
  needsGroup: false,
  moodleConnected: false,
  hasMoodleError: false,
  publicCalendarsLoading: false,
  hasPublicCalendarError: false,
);

DayAgenda _agenda(List<CalendarEntry> entries, {CalendarData? data}) =>
    DayAgenda(
      date: DateTime(2026, 5, 12),
      entries: entries,
      data: data ?? _healthy,
    );

void main() {
  group('current or next entry', () {
    test('an entry in progress wins over one that starts later', () {
      final DayAgenda agenda = _agenda(<CalendarEntry>[
        _entry('now', from: 10, to: 12),
        _entry('later', from: 14, to: 16),
      ]);
      expect(agenda.currentOrNext(_at(11))?.id, 'now');
    });

    test('between entries the next one is offered', () {
      final DayAgenda agenda = _agenda(<CalendarEntry>[
        _entry('morning', from: 8, to: 10),
        _entry('afternoon', from: 14, to: 16),
      ]);
      expect(agenda.currentOrNext(_at(12))?.id, 'afternoon');
    });

    test('the earliest of several upcoming entries wins', () {
      final DayAgenda agenda = _agenda(<CalendarEntry>[
        _entry('late', from: 18, to: 19),
        _entry('soon', from: 13, to: 14),
      ]);
      expect(agenda.currentOrNext(_at(12))?.id, 'soon');
    });

    test('once the day is over there is nothing to point at', () {
      final DayAgenda agenda = _agenda(<CalendarEntry>[
        _entry('done', from: 8, to: 10),
      ]);
      expect(
        agenda.currentOrNext(_at(20)),
        isNull,
        reason: 'a card must not point at something that already finished',
      );
    });

    test('an entry ending exactly now no longer counts as current', () {
      final DayAgenda agenda = _agenda(<CalendarEntry>[
        _entry('ending', from: 10, to: 12),
      ]);
      expect(agenda.currentOrNext(_at(12)), isNull);
    });

    test('all-day items never become the "right now" entry', () {
      // An all-day deadline is not something you are "in".
      final DayAgenda agenda = _agenda(<CalendarEntry>[
        _entry('deadline', from: 0, to: 23, allDay: true),
        _entry('lecture', from: 14, to: 16),
      ]);
      expect(agenda.currentOrNext(_at(10))?.id, 'lecture');
    });
  });

  group('the rest of the day', () {
    test('excludes the lead entry but keeps everything else ahead', () {
      final DayAgenda agenda = _agenda(<CalendarEntry>[
        _entry('now', from: 10, to: 12),
        _entry('next', from: 14, to: 16),
        _entry('past', from: 8, to: 9),
      ]);
      final List<String> ids = agenda
          .upcomingAfter(_at(11))
          .map((CalendarEntry e) => e.id)
          .toList();
      expect(ids, <String>['next']);
    });

    test('all-day items stay listed regardless of the clock', () {
      final DayAgenda agenda = _agenda(<CalendarEntry>[
        _entry('deadline', from: 0, to: 23, allDay: true),
        _entry('past', from: 8, to: 9),
      ]);
      final List<String> ids = agenda
          .upcomingAfter(_at(20))
          .map((CalendarEntry e) => e.id)
          .toList();
      expect(ids, <String>['deadline']);
    });
  });

  group('load state', () {
    test('an empty day while loading is not the same as an empty day', () {
      final CalendarData loading = CalendarData(
        entries: <CalendarEntry>[],
        enabledSources: <CalendarSource>{},
        timetableLoading: true,
        hasTimetableError: false,
        needsGroup: false,
        moodleConnected: false,
        hasMoodleError: false,
        publicCalendarsLoading: false,
        hasPublicCalendarError: false,
      );
      expect(_agenda(<CalendarEntry>[], data: loading).isLoading, isTrue);
      expect(_agenda(<CalendarEntry>[]).isLoading, isFalse);
    });

    test('one broken source does not count as a broken day', () {
      final CalendarData partly = CalendarData(
        entries: <CalendarEntry>[],
        enabledSources: <CalendarSource>{},
        timetableLoading: false,
        hasTimetableError: true,
        needsGroup: false,
        moodleConnected: false,
        hasMoodleError: false,
        publicCalendarsLoading: false,
        hasPublicCalendarError: false,
      );
      expect(
        _agenda(<CalendarEntry>[], data: partly).allSourcesFailed,
        isFalse,
        reason: 'the public calendars still worked',
      );
    });

    test('entries present means the day is fine even if a source failed', () {
      final CalendarData broken = CalendarData(
        entries: <CalendarEntry>[],
        enabledSources: <CalendarSource>{},
        timetableLoading: false,
        hasTimetableError: true,
        needsGroup: false,
        moodleConnected: false,
        hasMoodleError: false,
        publicCalendarsLoading: false,
        hasPublicCalendarError: true,
      );
      expect(
        _agenda(<CalendarEntry>[
          _entry('moodle', from: 9, to: 10, source: CalendarSource.moodle),
        ], data: broken).allSourcesFailed,
        isFalse,
      );
    });
  });
}
