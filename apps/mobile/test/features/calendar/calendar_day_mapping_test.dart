// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:campus_koethen/features/calendar/application/calendar_merge.dart';
import 'package:campus_koethen/features/calendar/application/calendar_providers.dart';
import 'package:campus_koethen/features/calendar/domain/calendar_entry.dart';
import 'package:flutter_test/flutter_test.dart';

/// Which local days an entry belongs to.
///
/// Two things go wrong here if nobody looks: the API sends absolute instants,
/// so reading `start.day` off a UTC value answers a question about London; and
/// an entry that runs over several days has more than one answer.
///
/// The zone-sensitive expectations are written against the **local** zone the
/// test runs in, not against a fixed offset, so they hold on a developer
/// machine in Köthen and on a CI runner. CI pins `TZ=Europe/Berlin` so the
/// distinction is actually exercised there.
CalendarEntry _timed(DateTime start, {DateTime? end, String id = 'e'}) =>
    CalendarEntry(
      id: id,
      source: CalendarSource.timetable,
      title: 'Vorlesung',
      start: start,
      end: end,
    );

CalendarEntry _allDay(DateTime start, {DateTime? end, String id = 'a'}) =>
    CalendarEntry(
      id: id,
      source: CalendarSource.publicCalendar,
      title: 'Prüfungszeitraum',
      start: start,
      end: end,
      allDay: true,
    );

CalendarData _data(List<CalendarEntry> entries) => CalendarData(
  entries: entries,
  enabledSources: <CalendarSource>{...kMergeableCalendarSources},
);

void main() {
  group('day key of a timed entry', () {
    test('is the local day, not the UTC one', () {
      // 00:30 local — in every zone ahead of UTC this instant is still the
      // previous day in UTC, which is precisely the reading that was wrong.
      final DateTime localStart = DateTime(2026, 2, 3, 0, 30);
      final CalendarEntry entry = _timed(localStart.toUtc());

      expect(entry.day, DateTime(2026, 2, 3));
      expect(entry.day, calendarDayKey(entry.start.toLocal()));
    });

    test('holds for any instant, whatever the runner zone', () {
      for (int hour = 0; hour < 24; hour++) {
        final DateTime local = DateTime(2026, 2, 3, hour, 15);
        expect(
          _timed(local.toUtc()).day,
          DateTime(2026, 2, 3),
          reason: 'an entry at $hour:15 local belongs to 2026-02-03',
        );
      }
    });
  });

  group('day key of an all-day entry', () {
    test('is the calendar date the API encoded as UTC midnight', () {
      // The worker stores a VALUE=DATE as UTC midnight on purpose, so that no
      // device zone can shift it. Reading it back in local time would move it
      // a day in every zone behind UTC.
      final CalendarEntry entry = _allDay(
        DateTime.utc(2026, 2, 3),
        end: DateTime.utc(2026, 2, 4), // ICS DTEND is exclusive
      );

      expect(entry.day, DateTime(2026, 2, 3));
      expect(entry.lastDay, DateTime(2026, 2, 3));
    });

    test('a locally built all-day entry keeps its own date', () {
      final CalendarEntry entry = _allDay(
        DateTime(2026, 2, 3),
        end: DateTime(2026, 2, 3, 23, 59),
      );
      expect(entry.day, DateTime(2026, 2, 3));
      expect(entry.lastDay, DateTime(2026, 2, 3));
    });
  });

  group('multi-day entries', () {
    final CalendarEntry examWeek = _allDay(
      DateTime.utc(2026, 2, 2),
      end: DateTime.utc(2026, 2, 7), // Mon–Fri, DTEND exclusive
      id: 'exam-week',
    );

    test('cover every day between the first and the last', () {
      expect(examWeek.day, DateTime(2026, 2, 2));
      expect(examWeek.lastDay, DateTime(2026, 2, 6));

      for (int d = 2; d <= 6; d++) {
        expect(
          entriesForDay(<CalendarEntry>[examWeek], DateTime(2026, 2, d)),
          hasLength(1),
          reason: 'the exam week runs on 2026-02-0$d',
        );
      }
      expect(
        entriesForDay(<CalendarEntry>[examWeek], DateTime(2026, 2, 1)),
        isEmpty,
      );
      expect(
        entriesForDay(<CalendarEntry>[examWeek], DateTime(2026, 2, 7)),
        isEmpty,
      );
    });

    test('mark every covered day in the day index', () {
      expect(calendarEventDays(<CalendarEntry>[examWeek]), <DateTime>{
        DateTime(2026, 2, 2),
        DateTime(2026, 2, 3),
        DateTime(2026, 2, 4),
        DateTime(2026, 2, 5),
        DateTime(2026, 2, 6),
      });
    });

    test('a timed entry running past midnight covers both days', () {
      final CalendarEntry night = _timed(
        DateTime(2026, 2, 3, 22).toUtc(),
        end: DateTime(2026, 2, 4, 1).toUtc(),
        id: 'night',
      );
      expect(night.day, DateTime(2026, 2, 3));
      expect(night.lastDay, DateTime(2026, 2, 4));
    });

    test('an entry ending exactly at midnight does not reach the next day', () {
      final CalendarEntry entry = _timed(
        DateTime(2026, 2, 3, 20).toUtc(),
        end: DateTime(2026, 2, 4).toUtc(),
        id: 'until-midnight',
      );
      expect(entry.lastDay, DateTime(2026, 2, 3));
    });

    test('an entry without an end covers only its own day', () {
      final CalendarEntry deadline = _timed(
        DateTime(2026, 2, 3, 23, 59).toUtc(),
        id: 'deadline',
      );
      expect(deadline.lastDay, deadline.day);
      expect(calendarEventDays(<CalendarEntry>[deadline]), hasLength(1));
    });
  });

  group('week strip counts', () {
    // The dot under a weekday and the list below it answered "which day?"
    // differently: the count read the UTC date fields off the instant, the
    // list converted to local first. An entry after local midnight therefore
    // hung under the previous day.
    test('count an entry under the day the list shows it on', () {
      final DateTime localStart = DateTime(2026, 7, 28, 0, 30);
      final CalendarEntry entry = _timed(
        localStart.toUtc(),
        id: 'nachtschicht',
      );
      final CalendarData data = _data(<CalendarEntry>[entry]);

      expect(data.forDay(DateTime(2026, 7, 28)), <CalendarEntry>[entry]);
      expect(data.entryCountsByDay[DateTime(2026, 7, 28)], 1);
      expect(
        data.entryCountsByDay[DateTime(2026, 7, 27)],
        isNull,
        reason:
            'nothing begins on the 27th, so that day carries no dot and '
            'the screen reader must not announce one',
      );
    });

    test('agree with the day list for every day of the week', () {
      final CalendarData data = _data(<CalendarEntry>[
        _timed(DateTime(2026, 7, 28, 0, 30).toUtc(), id: 'nacht'),
        _timed(DateTime(2026, 7, 28, 10).toUtc(), id: 'vorlesung'),
        _timed(DateTime(2026, 7, 30, 23, 45).toUtc(), id: 'spaet'),
        _allDay(DateTime.utc(2026, 7, 29), id: 'feiertag'),
      ]);

      for (int day = 27; day <= 31; day++) {
        final DateTime key = DateTime(2026, 7, day);
        expect(
          data.entryCountsByDay[key] ?? 0,
          data.forDay(key).length,
          reason: 'the dot under 2026-07-$day must match its day list',
        );
      }
    });

    test('count a multi-day entry on the day it begins', () {
      // Today's meaning of the dot: something *starts* here. The list shows
      // the exam week on all five days; widening the dot to match would be a
      // product change, so it is asserted rather than assumed.
      final CalendarEntry examWeek = _allDay(
        DateTime.utc(2026, 2, 2),
        end: DateTime.utc(2026, 2, 7),
        id: 'exam-week',
      );
      final CalendarData data = _data(<CalendarEntry>[examWeek]);

      expect(data.entryCountsByDay[DateTime(2026, 2, 2)], 1);
      expect(data.entryCountsByDay[DateTime(2026, 2, 4)], isNull);
      expect(data.forDay(DateTime(2026, 2, 4)), hasLength(1));
    });
  });
}
