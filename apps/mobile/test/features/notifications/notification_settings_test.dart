// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:campus_koethen/core/prefs/key_value_store.dart';
import 'package:campus_koethen/core/prefs/preference_keys.dart';
import 'package:campus_koethen/core/prefs/settings_controller.dart';
import 'package:campus_koethen/features/notifications/application/notification_settings_controller.dart';
import 'package:campus_koethen/features/notifications/domain/notification_category.dart';
import 'package:campus_koethen/features/notifications/domain/notification_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

ProviderContainer containerWith(KeyValueStore store) {
  final ProviderContainer container = ProviderContainer(
    overrides: <Override>[keyValueStoreProvider.overrideWithValue(store)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('a fresh installation is opted out and shows no prompt', () {
    final NotificationPreferences preferences = containerWith(
      InMemoryKeyValueStore(),
    ).read(notificationSettingsProvider);

    expect(preferences.optedIn, isFalse);
    expect(preferences.prePromptDeclined, isFalse);
  });

  test('every category is on after the opt-in (P2)', () async {
    final ProviderContainer container = containerWith(InMemoryKeyValueStore());
    await container
        .read(notificationSettingsProvider.notifier)
        .setOptedIn(true);

    final NotificationPreferences preferences = container.read(
      notificationSettingsProvider,
    );
    expect(preferences.optedIn, isTrue);
    expect(preferences.enabledCategories, NotificationCategory.values.toSet());
  });

  test('the opt-in and the category switches survive a restart', () async {
    final KeyValueStore store = InMemoryKeyValueStore();
    final ProviderContainer first = containerWith(store);
    await first.read(notificationSettingsProvider.notifier).setOptedIn(true);
    await first
        .read(notificationSettingsProvider.notifier)
        .setCategoryEnabled(NotificationCategory.canteenFavourite, false);

    // A second container over the same store is what a cold start looks like.
    final NotificationPreferences afterRestart = containerWith(
      store,
    ).read(notificationSettingsProvider);

    expect(afterRestart.optedIn, isTrue);
    expect(
      afterRestart.isCategoryEnabled(NotificationCategory.canteenFavourite),
      isFalse,
    );
    expect(
      afterRestart.isCategoryEnabled(NotificationCategory.dailySummary),
      isTrue,
    );
  });

  test(
    'switching a category back on removes it from the stored off-set',
    () async {
      final KeyValueStore store = InMemoryKeyValueStore();
      final ProviderContainer container = containerWith(store);
      final NotificationSettingsController controller = container.read(
        notificationSettingsProvider.notifier,
      );

      await controller.setCategoryEnabled(
        NotificationCategory.dailySummary,
        false,
      );
      await controller.setCategoryEnabled(
        NotificationCategory.dailySummary,
        true,
      );

      expect(
        store.getStringList(PreferenceKeys.notificationCategoriesDisabled),
        isEmpty,
      );
    },
  );

  test('a stored value from a category that no longer exists is ignored', () {
    final KeyValueStore store = InMemoryKeyValueStore(<String, Object>{
      PreferenceKeys.notificationCategoriesDisabled: <String>[
        'timetable',
        'summary',
      ],
    });

    final NotificationPreferences preferences = containerWith(
      store,
    ).read(notificationSettingsProvider);

    expect(preferences.disabledCategories, <NotificationCategory>{
      NotificationCategory.dailySummary,
    });
  });

  test('a corrupted preference degrades to the default, it never throws', () {
    final KeyValueStore store = InMemoryKeyValueStore(<String, Object>{
      PreferenceKeys.notificationsOptedIn: 'not an int',
      PreferenceKeys.notificationCategoriesDisabled: 42,
    });

    final NotificationPreferences preferences = containerWith(
      store,
    ).read(notificationSettingsProvider);

    expect(preferences.optedIn, isFalse);
    expect(preferences.disabledCategories, isEmpty);
  });

  test('declining the pre-permission sheet is remembered', () async {
    final KeyValueStore store = InMemoryKeyValueStore();
    await containerWith(
      store,
    ).read(notificationSettingsProvider.notifier).markPrePromptDeclined();

    expect(
      containerWith(store).read(notificationSettingsProvider).prePromptDeclined,
      isTrue,
    );
  });
}
