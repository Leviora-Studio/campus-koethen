// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/prefs/key_value_store.dart';
import '../../../core/prefs/preference_keys.dart';
import '../../../core/prefs/settings_controller.dart';
import '../data/canteen_models.dart';
import '../domain/canteen_filter.dart';
import '../domain/meal_taxonomy.dart';

/// Owns the locally stored canteen preferences.
///
/// Everything here stays on the device. Which allergens somebody avoids is
/// close to health information: there is neither an account to sync it to nor
/// any reason to send it anywhere, and nothing in this file logs it either.
class CanteenFilterController extends Notifier<CanteenFilter> {
  KeyValueStore get _store => ref.read(keyValueStoreProvider);

  @override
  CanteenFilter build() {
    final KeyValueStore store = ref.watch(keyValueStoreProvider);
    List<String> list(String key) =>
        store.getStringList(key) ?? const <String>[];

    return CanteenFilter(
      // A stored key this build no longer knows is dropped rather than kept as
      // a filter nothing can match.
      requiredTraits: list(
        PreferenceKeys.canteenTraits,
      ).map(MealTrait.fromKey).whereType<MealTrait>().toSet(),
      excludedAllergens: list(
        PreferenceKeys.canteenAllergens,
      ).map(MealAllergen.fromKey).whereType<MealAllergen>().toSet(),
      priceGroup:
          store.getString(PreferenceKeys.canteenPriceGroup) ??
          MealPrice.studentGroup,
      favourites: list(PreferenceKeys.canteenFavourites).toSet(),
    );
  }

  Future<void> toggleTrait(MealTrait trait) => _write(state.toggleTrait(trait));

  Future<void> toggleAllergen(MealAllergen allergen) =>
      _write(state.toggleAllergen(allergen));

  Future<void> toggleFavourite(Meal meal) =>
      _write(state.toggleFavourite(meal));

  Future<void> removeFavouriteNamed(String name) =>
      _write(state.removeFavouriteNamed(name));

  Future<void> setPriceGroup(String group) =>
      _write(state.withPriceGroup(group));

  Future<void> clear() => _write(state.cleared());

  Future<void> _write(CanteenFilter next) async {
    state = next;
    final KeyValueStore store = _store;
    // Sorted so an unchanged selection does not rewrite the store in a new
    // order on every launch.
    Future<void> put(String key, Iterable<String> values) =>
        store.setStringList(key, values.toList(growable: false)..sort());

    await put(
      PreferenceKeys.canteenTraits,
      next.requiredTraits.map((MealTrait trait) => trait.key),
    );
    await put(
      PreferenceKeys.canteenAllergens,
      next.excludedAllergens.map((MealAllergen allergen) => allergen.key),
    );
    await put(PreferenceKeys.canteenFavourites, next.favourites);
    await store.setString(PreferenceKeys.canteenPriceGroup, next.priceGroup);
  }
}

final NotifierProvider<CanteenFilterController, CanteenFilter>
canteenFilterProvider =
    NotifierProvider<CanteenFilterController, CanteenFilter>(
      CanteenFilterController.new,
    );
