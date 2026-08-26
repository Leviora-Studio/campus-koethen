// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:campus_koethen/core/locale/locale_mode.dart';
import 'package:campus_koethen/features/calendar/presentation/week_strip.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import "package:campus_koethen/core/theme/app_icons.dart";

import '../../support/pump_app.dart';

/// A Wednesday, so a swipe can be seen to keep the weekday.
final DateTime _wednesday = DateTime(2026, 5, 13);

Future<List<int>> _pumpStrip(
  WidgetTester tester, {
  DateTime? selected,
  DateTime? today,
  Locale locale = AppLocales.german,
  TextScaler textScaler = TextScaler.noScaling,
  List<DateTime>? selections,
  Set<DateTime>? eventDays,
  VoidCallback? onToday,
}) async {
  final List<int> shifts = <int>[];

  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  await pumpScreen(
    tester,
    Scaffold(
      body: WeekStrip(
        selected: selected ?? _wednesday,
        today: today ?? _wednesday,
        entryCounts: const <DateTime, int>{},
        eventDays: eventDays ?? const <DateTime>{},
        onSelect: (DateTime day) => selections?.add(day),
        onShiftWeeks: shifts.add,
        onToday: onToday ?? () {},
      ),
    ),
    locale: locale,
    textScaler: textScaler,
  );
  await tester.pumpAndSettle();
  return shifts;
}

void main() {
  group('swiping the strip', () {
    testWidgets('a swipe to the left moves one week forward', (
      WidgetTester tester,
    ) async {
      final List<int> shifts = await _pumpStrip(tester);

      await tester.fling(find.byType(WeekStrip), const Offset(-200, 0), 1000);
      await tester.pumpAndSettle();

      expect(shifts, <int>[1]);
    });

    testWidgets('a swipe to the right moves one week back', (
      WidgetTester tester,
    ) async {
      final List<int> shifts = await _pumpStrip(tester);

      await tester.fling(find.byType(WeekStrip), const Offset(200, 0), 1000);
      await tester.pumpAndSettle();

      expect(shifts, <int>[-1]);
    });

    testWidgets('exactly one week per swipe, however far the finger goes', (
      WidgetTester tester,
    ) async {
      // A calendar that jumped three weeks because the flick was quick would
      // be impossible to aim.
      final List<int> shifts = await _pumpStrip(tester);

      await tester.fling(find.byType(WeekStrip), const Offset(-360, 0), 4000);
      await tester.pumpAndSettle();

      expect(shifts, <int>[1]);
    });

    testWidgets('tapping a day still selects it', (WidgetTester tester) async {
      // The swipe must not swallow the taps the strip exists for.
      final List<DateTime> selections = <DateTime>[];
      final List<int> shifts = await _pumpStrip(tester, selections: selections);

      await tester.tap(find.text('15'));
      await tester.pumpAndSettle();

      expect(selections.single.day, 15);
      expect(shifts, isEmpty);
    });
  });

  group('arrow buttons', () {
    testWidgets('the right arrow moves one week forward', (
      WidgetTester tester,
    ) async {
      final List<int> shifts = await _pumpStrip(tester);

      await tester.tap(find.byIcon(AppIcons.chevron_right));
      await tester.pumpAndSettle();

      expect(shifts, <int>[1]);
    });

    testWidgets('the left arrow moves one week back', (
      WidgetTester tester,
    ) async {
      final List<int> shifts = await _pumpStrip(tester);

      await tester.tap(find.byIcon(AppIcons.chevron_left));
      await tester.pumpAndSettle();

      expect(shifts, <int>[-1]);
    });
  });

  group('finding your way back', () {
    testWidgets('names the month, which the day numbers alone do not', (
      WidgetTester tester,
    ) async {
      await _pumpStrip(tester);

      expect(find.text('Mai 2026'), findsOneWidget);
    });

    testWidgets('offers Today once the strip has moved away from it', (
      WidgetTester tester,
    ) async {
      await _pumpStrip(
        tester,
        selected: DateTime(2026, 7, 1),
        today: _wednesday,
      );

      expect(find.text('Heute'), findsOneWidget);
    });

    testWidgets('offers Today also in the current week', (
      WidgetTester tester,
    ) async {
      await _pumpStrip(tester, selected: _wednesday, today: _wednesday);

      expect(find.text('Heute'), findsOneWidget);
    });

    testWidgets('tapping Today calls onToday in the current week', (
      WidgetTester tester,
    ) async {
      bool todayCalled = false;
      await _pumpStrip(
        tester,
        selected: DateTime(2026, 5, 14),
        today: _wednesday,
        onToday: () => todayCalled = true,
      );

      await tester.tap(find.text('Heute'));
      await tester.pumpAndSettle();

      expect(todayCalled, isTrue);
    });

    testWidgets('Today button shares the row with the month label', (
      WidgetTester tester,
    ) async {
      await _pumpStrip(tester);

      final Finder monthFinder = find.byKey(const Key('weekStripMonthLabel'));
      final Finder todayFinder = find.text('Heute');

      final double monthCenterY = tester.getCenter(monthFinder).dy;
      final double todayCenterY = tester.getCenter(todayFinder).dy;

      expect(
        (monthCenterY - todayCenterY).abs(),
        lessThan(12),
        reason: 'Today button is in the same horizontal row as the month label',
      );
    });
  });

  testWidgets('renders in English', (WidgetTester tester) async {
    await _pumpStrip(
      tester,
      selected: DateTime(2026, 7, 1),
      today: _wednesday,
      locale: AppLocales.english,
    );

    expect(find.text('July 2026'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
  });

  testWidgets('survives a narrow phone with doubled text', (
    WidgetTester tester,
  ) async {
    tester.view.physicalSize = const Size(320, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await pumpScreen(
      tester,
      Scaffold(
        body: WeekStrip(
          selected: DateTime(2026, 7, 1),
          today: _wednesday,
          entryCounts: const <DateTime, int>{},
          eventDays: const <DateTime>{},
          onSelect: (DateTime _) {},
          onShiftWeeks: (int _) {},
          onToday: () {},
        ),
      ),
      textScaler: const TextScaler.linear(2),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Heute'), findsOneWidget);
    expect(find.byIcon(AppIcons.chevron_left), findsOneWidget);
    expect(find.byIcon(AppIcons.chevron_right), findsOneWidget);
  });

  testWidgets('marks every day a multi-day entry runs on, not only its first', (
    WidgetTester tester,
  ) async {
    // CAL-9. The dot came from `countsByStartDay`, which counts only the day
    // an entry BEGINS on, while the day list underneath uses `forDay` and
    // happily lists an entry passing through. Strip and list contradicted
    // each other about the same day.
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final DateTime tuesday = DateTime(2026, 5, 12);
    final DateTime thursday = DateTime(2026, 5, 14);

    await pumpScreen(
      tester,
      Scaffold(
        body: WeekStrip(
          selected: _wednesday,
          today: _wednesday,
          // One entry, starting on Tuesday…
          entryCounts: <DateTime, int>{tuesday: 1},
          // …but running through Thursday.
          eventDays: <DateTime>{tuesday, _wednesday, thursday},
          onSelect: (DateTime _) {},
          onShiftWeeks: (int _) {},
          onToday: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Three dots, one per occupied day — not one.
    final Iterable<Container> dots = tester
        .widgetList<Container>(find.byType(Container))
        .where(
          (Container c) =>
              (c.decoration as BoxDecoration?)?.shape == BoxShape.circle,
        );
    expect(dots, hasLength(3));
  });
}
