// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:campus_koethen/core/prefs/key_value_store.dart';
import 'package:campus_koethen/core/prefs/preference_keys.dart';
import 'package:campus_koethen/core/prefs/settings_controller.dart';
import 'package:campus_koethen/features/calendar/application/calendar_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

ProviderContainer _container(KeyValueStore store) {
  final ProviderContainer container = ProviderContainer(
    overrides: <Override>[keyValueStoreProvider.overrideWithValue(store)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  test('the week is Monday to Friday by default', () {
    // A teaching week is five days, and two empty columns cost a fifth of the
    // width of a phone.
    final ProviderContainer container = _container(InMemoryKeyValueStore());

    expect(container.read(calendarShowWeekendProvider), isFalse);
    expect(container.read(calendarWeekDayCountProvider), 5);
  });

  test('switching the weekend on gives seven columns', () async {
    final ProviderContainer container = _container(InMemoryKeyValueStore());

    await container.read(calendarShowWeekendProvider.notifier).set(true);

    expect(container.read(calendarWeekDayCountProvider), 7);
  });

  test('the choice survives a restart', () async {
    final InMemoryKeyValueStore store = InMemoryKeyValueStore();
    await _container(
      store,
    ).read(calendarShowWeekendProvider.notifier).set(true);

    expect(store.getInt(PreferenceKeys.calendarShowWeekend), 1);
    expect(_container(store).read(calendarShowWeekendProvider), isTrue);
  });

  test('switching it off again is stored too, not just forgotten', () async {
    final InMemoryKeyValueStore store = InMemoryKeyValueStore(<String, Object>{
      PreferenceKeys.calendarShowWeekend: 1,
    });
    final ProviderContainer container = _container(store);

    await container.read(calendarShowWeekendProvider.notifier).set(false);

    expect(store.getInt(PreferenceKeys.calendarShowWeekend), 0);
    expect(_container(store).read(calendarShowWeekendProvider), isFalse);
  });
}
