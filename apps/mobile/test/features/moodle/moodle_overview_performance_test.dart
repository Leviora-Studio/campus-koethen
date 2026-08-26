// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:campus_koethen/features/moodle/application/moodle_providers.dart';
import 'package:campus_koethen/features/moodle/domain/moodle_account.dart';
import 'package:campus_koethen/features/moodle/domain/moodle_cache.dart';
import 'package:campus_koethen/features/moodle/domain/moodle_course.dart';
import 'package:campus_koethen/features/moodle/presentation/moodle_overview_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_moodle.dart';
import '../../support/pump_app.dart';

void main() {
  testWidgets('builds a long cached course list lazily', (
    WidgetTester tester,
  ) async {
    final DateTime now = DateTime.utc(2026, 8, 24, 12);
    final tokens = InMemoryMoodleTokenStore()
      ..token = const MoodleToken(value: 'tok', userId: 7, username: 'demo');
    final cache = InMemoryMoodleCacheStore()
      ..courses = <MoodleCourse>[
        for (int index = 0; index < 80; index++)
          MoodleCourse(id: index, fullName: 'Kurs $index'),
      ]
      ..marks = MoodleSyncMarks(lastAttempt: now);

    await pumpScreen(
      tester,
      const MoodleOverviewScreen(),
      overrides: <Override>[
        moodleApiClientProvider.overrideWithValue(FakeMoodleApiClient()),
        moodleTokenStoreProvider.overrideWithValue(tokens),
        moodleCacheStoreProvider.overrideWithValue(cache),
        moodleClockProvider.overrideWithValue(MutableClock(now)),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.text('Kurs 0'), findsOneWidget);
    expect(
      find.text('Kurs 79'),
      findsNothing,
      reason: 'off-screen course tiles must not be built eagerly',
    );

    await tester.scrollUntilVisible(
      find.text('Kurs 79'),
      500,
      scrollable: find.descendant(
        of: find.byType(CustomScrollView),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.text('Kurs 79'), findsOneWidget);
  });
}
