// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:campus_koethen/features/moodle/application/moodle_providers.dart';
import 'package:campus_koethen/features/moodle/domain/moodle_account.dart';
import 'package:campus_koethen/features/moodle/domain/moodle_cache.dart';
import 'package:campus_koethen/features/moodle/domain/moodle_course.dart';
import 'package:campus_koethen/features/moodle/presentation/moodle_course_screen.dart';
import 'package:campus_koethen/features/moodle/presentation/moodle_screen.dart';
import 'package:campus_koethen/core/theme/app_colors.dart';
import 'package:campus_koethen/core/theme/app_icons.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_moodle.dart';
import '../../support/pump_app.dart';

List<Override> _overrides({
  required FakeMoodleApiClient api,
  required InMemoryMoodleTokenStore tokens,
  required InMemoryMoodleCacheStore cache,
  required MutableClock clock,
}) => <Override>[
  moodleApiClientProvider.overrideWithValue(api),
  moodleTokenStoreProvider.overrideWithValue(tokens),
  moodleCacheStoreProvider.overrideWithValue(cache),
  moodleClockProvider.overrideWithValue(clock),
];

void main() {
  final DateTime t0 = DateTime.utc(2026, 7, 26, 12);

  group('course tabs', _courseTabTests);

  testWidgets('shows the connect screen when disconnected', (
    WidgetTester tester,
  ) async {
    await pumpScreen(
      tester,
      const MoodleScreen(),
      overrides: _overrides(
        api: FakeMoodleApiClient(),
        tokens: InMemoryMoodleTokenStore(),
        cache: InMemoryMoodleCacheStore(),
        clock: MutableClock(t0),
      ),
    );
    await tester.pumpAndSettle();

    // The connect gate is shown, not the overview.
    expect(find.text('Mit Moodle verbinden'), findsOneWidget);
    expect(find.text('Meine Kurse'), findsNothing);
  });

  testWidgets('setup lock and shield follow the light and dark brand colour', (
    WidgetTester tester,
  ) async {
    for (final (ThemeMode mode, Color expected) in <(ThemeMode, Color)>[
      (ThemeMode.light, AppColors.light.primary),
      (ThemeMode.dark, AppColors.dark.primary),
    ]) {
      await pumpScreen(
        tester,
        const MoodleScreen(),
        themeMode: mode,
        overrides: _overrides(
          api: FakeMoodleApiClient(),
          tokens: InMemoryMoodleTokenStore(),
          cache: InMemoryMoodleCacheStore(),
          clock: MutableClock(t0),
        ),
      );
      await tester.pumpAndSettle();

      for (final IconData iconData in <IconData>[
        AppIcons.lock_outline,
        AppIcons.shield_outlined,
      ]) {
        final Icon icon = tester.widget<Icon>(find.byIcon(iconData));
        expect(icon.color, expected);
      }
    }
  });

  testWidgets('shows cached courses when connected', (
    WidgetTester tester,
  ) async {
    final tokens = InMemoryMoodleTokenStore()
      ..token = const MoodleToken(value: 'tok', userId: 7, username: 'demo');
    final cache = InMemoryMoodleCacheStore()
      ..courses = <MoodleCourse>[
        const MoodleCourse(id: 1, fullName: 'Beispielkurs Informatik'),
      ]
      // A recent attempt suppresses the automatic sync in this test.
      ..marks = MoodleSyncMarks(lastAttempt: t0);

    await pumpScreen(
      tester,
      const MoodleScreen(),
      overrides: _overrides(
        api: FakeMoodleApiClient(),
        tokens: tokens,
        cache: cache,
        clock: MutableClock(t0),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Beispielkurs Informatik'), findsOneWidget);
    final Icon courseIcon = tester.widget<Icon>(
      find.byIcon(AppIcons.book_outlined),
    );
    expect(courseIcon.color, AppColors.light.primary);
  });

  testWidgets('course tiles omit Moodle completion progress', (
    WidgetTester tester,
  ) async {
    final tokens = InMemoryMoodleTokenStore()
      ..token = const MoodleToken(value: 'tok', userId: 7, username: 'demo');
    final cache = InMemoryMoodleCacheStore()
      ..courses = <MoodleCourse>[
        const MoodleCourse(
          id: 1,
          fullName: 'Beispielkurs Informatik',
          shortName: 'INF',
          progress: 73,
        ),
      ]
      ..marks = MoodleSyncMarks(lastAttempt: t0);

    await pumpScreen(
      tester,
      const MoodleScreen(),
      overrides: _overrides(
        api: FakeMoodleApiClient(),
        tokens: tokens,
        cache: cache,
        clock: MutableClock(t0),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('INF'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('course book icon follows the dark brand colour', (
    WidgetTester tester,
  ) async {
    final tokens = InMemoryMoodleTokenStore()
      ..token = const MoodleToken(value: 'tok', userId: 7, username: 'demo');
    final cache = InMemoryMoodleCacheStore()
      ..courses = <MoodleCourse>[
        const MoodleCourse(id: 1, fullName: 'Beispielkurs Informatik'),
      ]
      ..marks = MoodleSyncMarks(lastAttempt: t0);

    await pumpScreen(
      tester,
      const MoodleScreen(),
      themeMode: ThemeMode.dark,
      overrides: _overrides(
        api: FakeMoodleApiClient(),
        tokens: tokens,
        cache: cache,
        clock: MutableClock(t0),
      ),
    );
    await tester.pumpAndSettle();

    final Icon courseIcon = tester.widget<Icon>(
      find.byIcon(AppIcons.book_outlined),
    );
    expect(courseIcon.color, AppColors.dark.primary);
  });

  testWidgets('the local search filters the loaded courses', (
    WidgetTester tester,
  ) async {
    // Purely local: the fake API records every call, and none may happen while
    // typing. Moodle data never leaves the device.
    final api = FakeMoodleApiClient();
    final tokens = InMemoryMoodleTokenStore()
      ..token = const MoodleToken(value: 'tok', userId: 7, username: 'demo');
    final cache = InMemoryMoodleCacheStore()
      ..courses = <MoodleCourse>[
        const MoodleCourse(id: 1, fullName: 'Einführung in die Programmierung'),
        const MoodleCourse(id: 2, fullName: 'Rechnernetze', shortName: 'RN'),
      ]
      ..marks = MoodleSyncMarks(lastAttempt: t0);

    await pumpScreen(
      tester,
      const MoodleScreen(),
      overrides: _overrides(
        api: api,
        tokens: tokens,
        cache: cache,
        clock: MutableClock(t0),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Kurse durchsuchen'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'einfuehrung');
    await tester.pumpAndSettle();

    expect(find.text('Einführung in die Programmierung'), findsOneWidget);
    expect(find.text('Rechnernetze'), findsNothing);
  });

  testWidgets('a search without matches says so instead of showing nothing', (
    WidgetTester tester,
  ) async {
    final tokens = InMemoryMoodleTokenStore()
      ..token = const MoodleToken(value: 'tok', userId: 7, username: 'demo');
    final cache = InMemoryMoodleCacheStore()
      ..courses = <MoodleCourse>[
        const MoodleCourse(id: 1, fullName: 'Rechnernetze'),
      ]
      ..marks = MoodleSyncMarks(lastAttempt: t0);

    await pumpScreen(
      tester,
      const MoodleScreen(),
      overrides: _overrides(
        api: FakeMoodleApiClient(),
        tokens: tokens,
        cache: cache,
        clock: MutableClock(t0),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Kurse durchsuchen'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'quantenphysik');
    await tester.pumpAndSettle();

    expect(find.text('Kein passender Kurs'), findsOneWidget);
  });

  testWidgets('closing the search restores the whole list', (
    WidgetTester tester,
  ) async {
    final tokens = InMemoryMoodleTokenStore()
      ..token = const MoodleToken(value: 'tok', userId: 7, username: 'demo');
    final cache = InMemoryMoodleCacheStore()
      ..courses = <MoodleCourse>[
        const MoodleCourse(id: 1, fullName: 'Rechnernetze'),
      ]
      ..marks = MoodleSyncMarks(lastAttempt: t0);

    await pumpScreen(
      tester,
      const MoodleScreen(),
      overrides: _overrides(
        api: FakeMoodleApiClient(),
        tokens: tokens,
        cache: cache,
        clock: MutableClock(t0),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byTooltip('Kurse durchsuchen'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'quantenphysik');
    await tester.pumpAndSettle();
    expect(find.text('Rechnernetze'), findsNothing);

    // Closing clears the term, so a forgotten filter cannot hide everything.
    // The toggle renames itself while the search is open — one button doing
    // two opposite things must not claim to do only one of them.
    await tester.tap(find.byTooltip('Suche schließen'));
    await tester.pumpAndSettle();
    expect(find.text('Rechnernetze'), findsOneWidget);
  });
}

/// The three tab titles must stay readable where they are hardest to fit.
void _courseTabTests() {
  final DateTime t0 = DateTime.utc(2026, 7, 26, 12);

  Future<void> pumpCourse(
    WidgetTester tester, {
    required Size surface,
    TextScaler textScaler = TextScaler.noScaling,
  }) async {
    tester.view.physicalSize = surface;
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    final tokens = InMemoryMoodleTokenStore()
      ..token = const MoodleToken(value: 'tok', userId: 7, username: 'demo');

    await pumpScreen(
      tester,
      const MoodleCourseScreen(courseId: 1),
      textScaler: textScaler,
      overrides: _overrides(
        api: FakeMoodleApiClient(),
        tokens: tokens,
        cache: InMemoryMoodleCacheStore(),
        clock: MutableClock(t0),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
  }

  testWidgets('all three titles are written out on a narrow phone', (
    WidgetTester tester,
  ) async {
    await pumpCourse(tester, surface: const Size(320, 640));

    expect(find.text('Inhalte'), findsOneWidget);
    expect(find.text('Aufgaben'), findsOneWidget);
    // The long one: three equal thirds of 320 px cannot hold it.
    expect(find.text('Ankündigungen'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('and survive doubled text', (WidgetTester tester) async {
    await pumpCourse(
      tester,
      surface: const Size(320, 900),
      textScaler: const TextScaler.linear(2),
    );

    expect(find.text('Ankündigungen'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('the bar scrolls rather than shrinking the labels', (
    WidgetTester tester,
  ) async {
    await pumpCourse(tester, surface: const Size(320, 640));
    final TabBar bar = tester.widget<TabBar>(find.byType(TabBar));
    expect(bar.isScrollable, isTrue);
  });
}
