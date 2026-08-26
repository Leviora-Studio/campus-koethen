// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/prefs/key_value_store.dart';
import '../../../core/prefs/preference_keys.dart';
import '../../../core/prefs/settings_controller.dart';
import '../domain/notification_category.dart';
import '../domain/notification_preferences.dart';

/// Reads and writes [NotificationPreferences].
///
/// Three scalars in `shared_preferences`, nothing more. They survive a restart
/// because they are written the moment they change, and they survive a
/// reinstall not at all — which is correct: an opt-in is a decision about this
/// installation, and there is nowhere else it could have been kept.
class NotificationSettingsController extends Notifier<NotificationPreferences> {
  KeyValueStore get _store => ref.read(keyValueStoreProvider);

  @override
  NotificationPreferences build() {
    final KeyValueStore store = ref.watch(keyValueStoreProvider);
    return NotificationPreferences(
      optedIn: store.getInt(PreferenceKeys.notificationsOptedIn) == 1,
      disabledCategories: _readDisabled(store),
      prePromptDeclined:
          store.getInt(PreferenceKeys.notificationsPrePromptDeclined) == 1,
    );
  }

  /// An unknown stored value is ignored rather than repaired: it can only come
  /// from a category a later version removed, and dropping it silently turns
  /// notifications back **on** for something that no longer exists — which is
  /// nothing.
  static Set<NotificationCategory> _readDisabled(KeyValueStore store) {
    final List<String>? stored = store.getStringList(
      PreferenceKeys.notificationCategoriesDisabled,
    );
    if (stored == null) return const <NotificationCategory>{};
    return <NotificationCategory>{
      for (final String value in stored)
        if (NotificationCategory.fromStorage(value)
            case final NotificationCategory c)
          c,
    };
  }

  /// Turns the whole feature on or off.
  ///
  /// Switching off does not itself cancel anything — the plan simply becomes
  /// empty, and the scheduler clears the pending entries when it applies it.
  /// One path, so "off" cannot mean two different things.
  Future<void> setOptedIn(bool value) async {
    if (state.optedIn == value) return;
    state = state.copyWith(optedIn: value);
    await _store.setInt(PreferenceKeys.notificationsOptedIn, value ? 1 : 0);
  }

  Future<void> setCategoryEnabled(
    NotificationCategory category,
    bool enabled,
  ) async {
    final Set<NotificationCategory> next = <NotificationCategory>{
      ...state.disabledCategories,
    };
    if (enabled) {
      next.remove(category);
    } else {
      next.add(category);
    }
    if (next.length == state.disabledCategories.length &&
        next.containsAll(state.disabledCategories)) {
      return;
    }
    state = state.copyWith(disabledCategories: next);
    await _store.setStringList(
      PreferenceKeys.notificationCategoriesDisabled,
      next
          .map((NotificationCategory c) => c.storageValue)
          .toList(growable: false),
    );
  }

  /// Records that the reader closed the pre-permission sheet without asking
  /// the operating system.
  Future<void> markPrePromptDeclined() async {
    if (state.prePromptDeclined) return;
    state = state.copyWith(prePromptDeclined: true);
    await _store.setInt(PreferenceKeys.notificationsPrePromptDeclined, 1);
  }
}

/// The reader's local notification settings.
final NotifierProvider<NotificationSettingsController, NotificationPreferences>
notificationSettingsProvider =
    NotifierProvider<NotificationSettingsController, NotificationPreferences>(
      NotificationSettingsController.new,
    );
