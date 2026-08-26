// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:campus_koethen/core/prefs/key_value_store.dart';
import 'package:campus_koethen/core/prefs/preference_keys.dart';
import 'package:campus_koethen/core/prefs/settings_controller.dart';
import 'package:campus_koethen/features/timetable/application/timetable_providers.dart';
import 'package:campus_koethen/features/timetable/application/timetable_week.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../../support/fixtures.dart';

ProviderContainer containerWith(KeyValueStore store) {
  final ProviderContainer container = ProviderContainer(
    overrides: <Override>[keyValueStoreProvider.overrideWithValue(store)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('selected group', () {
    test('is empty until the user picks one', () {
      final ProviderContainer container = containerWith(
        InMemoryKeyValueStore(),
      );

      expect(container.read(selectedTimetableGroupIdProvider), isNull);
    });

    test('survives a restart of the app', () async {
      final InMemoryKeyValueStore store = InMemoryKeyValueStore();

      await containerWith(store)
          .read(settingsProvider.notifier)
          .setTimetableGroup(timetableGroupIdFixture);

      expect(
        store.getString(PreferenceKeys.preferredTimetableGroup),
        timetableGroupIdFixture,
        reason: 'only the Campus UUID is ever persisted',
      );
      expect(
        containerWith(store).read(selectedTimetableGroupIdProvider),
        timetableGroupIdFixture,
        reason: 'a fresh container reads the stored choice',
      );
    });

    test('can be cleared again', () async {
      final InMemoryKeyValueStore store = InMemoryKeyValueStore(
        <String, Object>{
          PreferenceKeys.preferredTimetableGroup: timetableGroupIdFixture,
        },
      );
      final ProviderContainer container = containerWith(store);

      await container.read(settingsProvider.notifier).setTimetableGroup(null);

      expect(container.read(selectedTimetableGroupIdProvider), isNull);
      expect(store.getString(PreferenceKeys.preferredTimetableGroup), isNull);
    });
  });

  group('week arithmetic', () {
    test('always starts on Monday', () {
      for (int day = 20; day <= 26; day++) {
        expect(
          TimetableWeek.startOf(DateTime(2026, 7, day)),
          DateTime(2026, 7, 20),
          reason: '2026-07-$day belongs to the week of the 20th',
        );
      }
      expect(
        TimetableWeek.startOf(DateTime(2026, 7, 27)),
        DateTime(2026, 7, 27),
      );
    });

    test('ends six days later and crosses month boundaries', () {
      expect(TimetableWeek.endOf(DateTime(2026, 7, 30)), DateTime(2026, 8, 2));
      expect(TimetableWeek.daysOf(DateTime(2026, 7, 30)), hasLength(7));
      expect(
        TimetableWeek.daysOf(DateTime(2026, 7, 30)).last,
        DateTime(2026, 8, 2),
      );
    });

    test('drops the time of day', () {
      expect(
        TimetableWeek.startOf(DateTime(2026, 7, 22, 23, 45)),
        DateTime(2026, 7, 20),
      );
    });
  });

  group('selected day', () {
    test('defaults to today', () {
      final ProviderContainer container = containerWith(
        InMemoryKeyValueStore(),
      );
      final DateTime now = DateTime.now();

      expect(
        container.read(selectedTimetableDayProvider),
        DateTime(now.year, now.month, now.day),
      );
    });

    test('week navigation keeps the weekday', () {
      final ProviderContainer container = containerWith(
        InMemoryKeyValueStore(),
      );
      final SelectedTimetableDayController controller = container.read(
        selectedTimetableDayProvider.notifier,
      );

      controller.select(DateTime(2026, 7, 22));
      controller.nextWeek();
      expect(
        container.read(selectedTimetableDayProvider),
        DateTime(2026, 7, 29),
      );

      controller.previousWeek();
      controller.previousWeek();
      expect(
        container.read(selectedTimetableDayProvider),
        DateTime(2026, 7, 15),
      );
    });

    test('jumping to today restores the current day', () {
      final ProviderContainer container = containerWith(
        InMemoryKeyValueStore(),
      );
      final SelectedTimetableDayController controller = container.read(
        selectedTimetableDayProvider.notifier,
      );
      final DateTime now = DateTime.now();

      controller.select(DateTime(2020, 1, 1));
      controller.today();

      expect(
        container.read(selectedTimetableDayProvider),
        DateTime(now.year, now.month, now.day),
      );
    });
  });

  group('TimetableWeekRequest', () {
    test(
      'is a value type so the provider family caches per group and week',
      () {
        const String other = '22222222-2222-4222-8222-222222222222';
        final TimetableWeekRequest a = TimetableWeekRequest(
          groupId: timetableGroupIdFixture,
          weekStart: DateTime(2026, 7, 20),
        );
        final TimetableWeekRequest b = TimetableWeekRequest(
          groupId: timetableGroupIdFixture,
          weekStart: DateTime(2026, 7, 20),
        );

        expect(a, b);
        expect(a.hashCode, b.hashCode);
        expect(
          a,
          isNot(
            TimetableWeekRequest(
              groupId: other,
              weekStart: DateTime(2026, 7, 20),
            ),
          ),
        );
        expect(
          a,
          isNot(
            TimetableWeekRequest(
              groupId: timetableGroupIdFixture,
              weekStart: DateTime(2026, 7, 27),
            ),
          ),
        );
        expect(a.weekEnd, DateTime(2026, 7, 26));
      },
    );
  });
}
