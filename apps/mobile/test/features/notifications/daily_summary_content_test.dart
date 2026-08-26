// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

/// The visible text of the 08:00 overview, in both languages.
///
/// The privacy rule of P10 is checked here rather than reasoned about: the
/// body is searched for the course and assignment titles it was built next
/// to, and must not contain them.
library;

import 'dart:ui' show Locale;

import 'package:campus_koethen/features/notifications/application/daily_summary.dart';
import 'package:campus_koethen/features/notifications/application/daily_summary_content.dart';
import 'package:campus_koethen/features/notifications/domain/notification_category.dart';
import 'package:campus_koethen/features/notifications/domain/notification_request.dart';
import 'package:campus_koethen/l10n/l10n.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

late AppLocalizations de;
late AppLocalizations en;

NotificationRequest? build(DailySummaryDay day, {String locale = 'de'}) =>
    dailySummaryRequest(
      day: day,
      l10n: locale == 'de' ? de : en,
      localeCode: locale,
    );

void main() {
  setUpAll(() {
    // In the app the localisation delegates do this before the notification
    // host is ever built; a plain unit test has to say so itself.
    initializeDateFormatting();
    de = lookupAppLocalizations(const Locale('de'));
    en = lookupAppLocalizations(const Locale('en'));
  });

  final DateTime day = DateTime(2026, 8, 24);

  test('an empty day produces no notification at all', () {
    expect(build(DailySummaryDay(day: day)), isNull);
  });

  test('a normal day reads the way the UX spec writes it', () {
    final NotificationRequest request = build(
      DailySummaryDay(
        day: day,
        lectureCount: 3,
        firstLectureStart: DateTime(2026, 8, 24, 8, 30),
        moodleDeadlineCount: 1,
        hasCanteenMenu: true,
      ),
    )!;

    expect(request.title, 'Guten Morgen! Dein Tag am Campus');
    expect(
      request.body,
      'Heute 3 Vorlesungen (erste um 08:30 Uhr), 1 Moodle-Abgabefrist und '
      'Speiseplan verfügbar.',
    );
  });

  test('the same day in English', () {
    final NotificationRequest request = build(
      DailySummaryDay(
        day: day,
        lectureCount: 3,
        firstLectureStart: DateTime(2026, 8, 24, 8, 30),
        moodleDeadlineCount: 1,
        hasCanteenMenu: true,
      ),
      locale: 'en',
    )!;

    expect(request.title, 'Good morning! Your campus day');
    expect(
      request.body,
      'Today: 3 lectures (first at 08:30), 1 Moodle submission deadline and '
      'canteen menu available.',
    );
  });

  group('Moodle stays neutral (P10)', () {
    test('neither a course nor an assignment title can reach the text', () {
      // The aggregation has no field for either, which is the actual
      // guarantee; this checks the text builder does not invent one.
      for (final AppLocalizations l10n in <AppLocalizations>[de, en]) {
        final NotificationRequest request = dailySummaryRequest(
          day: DailySummaryDay(day: day, moodleDeadlineCount: 2),
          l10n: l10n,
          localeCode: l10n.localeName,
        )!;

        expect(request.body, isNot(contains('Übungsblatt')));
        expect(request.body, isNot(contains('Datenbanken')));
        expect(request.body, contains('2'));
      }
    });

    test('a day with a deadline is marked as needing a neutral preview', () {
      expect(
        build(DailySummaryDay(day: day, moodleDeadlineCount: 1))!.visibility,
        NotificationVisibility.neutral,
      );
    });

    test('a day without one may show its public detail in full (P9)', () {
      expect(
        build(
          DailySummaryDay(
            day: day,
            eventCount: 1,
            singleEventTitle: 'Campus Sommerfest',
            singleEventStart: DateTime(2026, 8, 24, 16),
          ),
        )!.visibility,
        NotificationVisibility.publicContent,
      );
    });
  });

  group('the body stays short', () {
    test('a single event is named, several are counted', () {
      expect(
        build(
          DailySummaryDay(
            day: day,
            eventCount: 1,
            singleEventTitle: 'Campus Sommerfest',
            singleEventStart: DateTime(2026, 8, 24, 16),
          ),
        )!.body,
        'Heute »Campus Sommerfest« um 16:00 Uhr.',
      );
      expect(
        build(DailySummaryDay(day: day, eventCount: 4))!.body,
        'Heute 4 Termine.',
      );
    });

    test('an all-day event is named without a meaningless time', () {
      expect(
        build(
          DailySummaryDay(
            day: day,
            eventCount: 1,
            singleEventTitle: 'Prüfungszeitraum',
            singleEventAllDay: true,
          ),
        )!.body,
        'Heute »Prüfungszeitraum«.',
      );
    });

    test('a favourite dish replaces the plain menu mention', () {
      expect(
        build(
          DailySummaryDay(
            day: day,
            lectureCount: 1,
            hasCanteenMenu: true,
            favouriteMealName: 'Käsespätzle',
          ),
        )!.body,
        'Heute 1 Vorlesung und »Käsespätzle« in der Mensa.',
      );
    });

    test('a fully loaded day still names at most four things', () {
      final String body = build(
        DailySummaryDay(
          day: day,
          lectureCount: 6,
          firstLectureStart: DateTime(2026, 8, 24, 8),
          eventCount: 5,
          moodleDeadlineCount: 3,
          hasCanteenMenu: true,
          favouriteMealName: 'Käsespätzle',
        ),
      )!.body;

      expect(
        body,
        'Heute 6 Vorlesungen (erste um 08:00 Uhr), 5 Termine, '
        '3 Moodle-Abgabefristen und »Käsespätzle« in der Mensa.',
      );
    });
  });

  group('scheduling identity', () {
    test('the day is the target, so the tap can open exactly it', () {
      final NotificationRequest request = build(
        DailySummaryDay(day: day, lectureCount: 1),
      )!;

      expect(request.category, NotificationCategory.dailySummary);
      expect(request.target, '2026-08-24');
      expect(request.key, 'n2:2026-08-24');
      expect(request.payload.toStorage(), 'v1|daily.summary|2026-08-24');
    });

    test('the trigger is 08:00 wall-clock time on that day (P4)', () {
      final NotificationRequest request = build(
        DailySummaryDay(day: day, lectureCount: 1),
      )!;

      expect(
        request.trigger,
        LocalTimeTrigger(day: day, hour: 8),
        reason:
            'A wall-clock trigger, never an instant: 08:00 has to stay 08:00 '
            'on the dial when the clocks change.',
      );
      expect(kDailySummaryHour, 8);
    });
  });
}
