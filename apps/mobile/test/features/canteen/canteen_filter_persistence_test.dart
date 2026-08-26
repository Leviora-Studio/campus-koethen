// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:campus_koethen/core/prefs/key_value_store.dart';
import 'package:campus_koethen/core/prefs/preference_keys.dart';
import 'package:campus_koethen/core/prefs/settings_controller.dart';
import 'package:campus_koethen/features/canteen/application/canteen_filter_controller.dart';
import 'package:campus_koethen/features/canteen/data/canteen_models.dart';
import 'package:campus_koethen/features/canteen/domain/canteen_filter.dart';
import 'package:campus_koethen/features/canteen/domain/meal_taxonomy.dart';
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
  test('a fresh install has no filter at all', () {
    final CanteenFilter filter = _container(
      InMemoryKeyValueStore(),
    ).read(canteenFilterProvider);
    expect(filter, CanteenFilter.none);
    expect(filter.isActive, isFalse);
    expect(filter.priceGroup, MealPrice.studentGroup);
  });

  test('every part of the filter survives a restart', () async {
    final InMemoryKeyValueStore store = InMemoryKeyValueStore();
    final CanteenFilterController controller = _container(
      store,
    ).read(canteenFilterProvider.notifier);

    await controller.toggleTrait(MealTrait.vegan);
    await controller.toggleAllergen(MealAllergen.nutsAlmond);
    await controller.setPriceGroup('employee');
    await controller.toggleFavourite(const Meal(id: 'x', name: 'Gemüsepfanne'));

    final CanteenFilter reloaded = _container(
      store,
    ).read(canteenFilterProvider);
    expect(reloaded.requiredTraits, <MealTrait>{MealTrait.vegan});
    expect(reloaded.excludedAllergens, <MealAllergen>{MealAllergen.nutsAlmond});
    expect(reloaded.priceGroup, 'employee');
    expect(reloaded.favourites, <String>{'Gemüsepfanne'});
  });

  test('stable keys are stored, not localised labels', () async {
    // The store has to survive a language change and an app update.
    final InMemoryKeyValueStore store = InMemoryKeyValueStore();
    final CanteenFilterController controller = _container(
      store,
    ).read(canteenFilterProvider.notifier);

    await controller.toggleTrait(MealTrait.vegan);
    await controller.toggleAllergen(MealAllergen.glutenWheat);

    expect(store.getStringList(PreferenceKeys.canteenTraits), <String>[
      'vegan',
    ]);
    expect(store.getStringList(PreferenceKeys.canteenAllergens), <String>[
      'gluten_wheat',
    ]);
  });

  test('the old code-based filters are not adopted', () async {
    // "Avoid code 52" means nothing in the new vocabulary, and reading it as a
    // semantic key would turn it into a filter the user never set.
    final InMemoryKeyValueStore store = InMemoryKeyValueStore(<String, Object>{
      'canteen.filter.required.v1': <String>['52'],
      'canteen.filter.excluded.v1': <String>['A1', 'G2'],
      'canteen.hidden.v1': <String>['Leber'],
      'canteen.filter.favOnly.v1': 1,
    });

    final CanteenFilter filter = _container(store).read(canteenFilterProvider);

    expect(filter.requiredTraits, isEmpty);
    expect(filter.excludedAllergens, isEmpty);
    expect(filter.isActive, isFalse);
  });

  test('an unknown stored key is dropped, not kept as a dead filter', () async {
    final InMemoryKeyValueStore store = InMemoryKeyValueStore(<String, Object>{
      PreferenceKeys.canteenAllergens: <String>['nuts', 'a-key-we-removed'],
    });

    expect(
      _container(store).read(canteenFilterProvider).excludedAllergens,
      <MealAllergen>{MealAllergen.nuts},
    );
  });

  test('the price group defaults to student when nothing is stored', () {
    final InMemoryKeyValueStore store = InMemoryKeyValueStore();
    expect(_container(store).read(canteenFilterProvider).priceGroup, 'student');
  });

  test('sets are written in a stable order', () async {
    // Otherwise an unchanged selection would rewrite the store in a new order
    // on every launch.
    final InMemoryKeyValueStore store = InMemoryKeyValueStore();
    final CanteenFilterController controller = _container(
      store,
    ).read(canteenFilterProvider.notifier);

    await controller.toggleAllergen(MealAllergen.soy);
    await controller.toggleAllergen(MealAllergen.egg);
    await controller.toggleAllergen(MealAllergen.milk);

    expect(store.getStringList(PreferenceKeys.canteenAllergens), <String>[
      'egg',
      'milk',
      'soy',
    ]);
  });

  test('clearing keeps favourites and the price group on disk', () async {
    final InMemoryKeyValueStore store = InMemoryKeyValueStore();
    final CanteenFilterController controller = _container(
      store,
    ).read(canteenFilterProvider.notifier);

    await controller.toggleTrait(MealTrait.vegan);
    await controller.setPriceGroup('guest');
    await controller.toggleFavourite(const Meal(id: 'x', name: 'Pasta'));
    await controller.clear();

    expect(store.getStringList(PreferenceKeys.canteenTraits), isEmpty);
    expect(store.getStringList(PreferenceKeys.canteenFavourites), <String>[
      'Pasta',
    ]);
    expect(store.getString(PreferenceKeys.canteenPriceGroup), 'guest');
  });
}
