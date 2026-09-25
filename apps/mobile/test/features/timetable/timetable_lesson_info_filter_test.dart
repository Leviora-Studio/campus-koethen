// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:campus_koethen/core/prefs/key_value_store.dart';
import 'package:campus_koethen/core/prefs/preference_keys.dart';
import 'package:campus_koethen/core/prefs/settings_controller.dart';
import 'package:campus_koethen/features/timetable/application/timetable_lesson_info_filter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('all exact values and missing information are visible by default', () {
    final InMemoryKeyValueStore store = InMemoryKeyValueStore(<String, Object>{
      PreferenceKeys.preferredTimetableGroup: 'group-a',
    });
    final ProviderContainer container = ProviderContainer(
      overrides: [keyValueStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);

    final TimetableLessonInfoFilter filter = container.read(
      timetableLessonInfoFilterProvider,
    );
    expect(filter.accepts('P1'), isTrue);
    expect(filter.accepts('Gruppe1'), isTrue);
    expect(filter.accepts(null), isTrue);
  });

  test(
    'deselecting one exact value persists without hiding variants or new values',
    () async {
      final InMemoryKeyValueStore store = InMemoryKeyValueStore(
        <String, Object>{PreferenceKeys.preferredTimetableGroup: 'group-a'},
      );
      final ProviderContainer container = ProviderContainer(
        overrides: [keyValueStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);

      await container
          .read(timetableLessonInfoFilterProvider.notifier)
          .setSelected('P1', selected: false);
      expect(
        container.read(timetableLessonInfoFilterProvider).accepts('P1'),
        isFalse,
      );
      expect(
        container.read(timetableLessonInfoFilterProvider).accepts('Gruppe1'),
        isTrue,
      );
      expect(
        container.read(timetableLessonInfoFilterProvider).accepts(' P1 '),
        isTrue,
      );
      expect(
        container.read(timetableLessonInfoFilterProvider).accepts('P2'),
        isTrue,
      );

      container.invalidate(timetableLessonInfoFilterProvider);
      expect(
        container.read(timetableLessonInfoFilterProvider).accepts('P1'),
        isFalse,
      );

      await container
          .read(settingsProvider.notifier)
          .setTimetableGroup('group-b');
      expect(
        container.read(timetableLessonInfoFilterProvider).accepts('P1'),
        isTrue,
      );
      await container
          .read(settingsProvider.notifier)
          .setTimetableGroup('group-a');
      expect(
        container.read(timetableLessonInfoFilterProvider).accepts('P1'),
        isFalse,
      );
    },
  );

  test('lessons without information can be hidden independently', () async {
    final InMemoryKeyValueStore store = InMemoryKeyValueStore(<String, Object>{
      PreferenceKeys.preferredTimetableGroup: 'group-a',
    });
    final ProviderContainer container = ProviderContainer(
      overrides: [keyValueStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);

    await container
        .read(timetableLessonInfoFilterProvider.notifier)
        .setWithoutInfoSelected(false);
    expect(
      container.read(timetableLessonInfoFilterProvider).accepts(null),
      isFalse,
    );
    expect(
      container.read(timetableLessonInfoFilterProvider).accepts('P1'),
      isTrue,
    );
  });
}
