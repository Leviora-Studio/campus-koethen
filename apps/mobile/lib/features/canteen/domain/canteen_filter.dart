// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:flutter/foundation.dart';

import '../data/canteen_models.dart';
import 'meal_taxonomy.dart';

/// The user's local canteen preferences.
///
/// Everything here stays on the device. Which allergens somebody avoids is
/// close to health information: it is never sent to a backend, never logged and
/// never used for anything but deciding what this screen shows.
///
/// The filter works on the API's **stable semantic keys**, not on the source's
/// marker codes or its German labels — see [MealTrait] and [MealAllergen] for
/// why that distinction matters on food.
@immutable
class CanteenFilter {
  CanteenFilter({
    this.requiredTraits = const <MealTrait>{},
    this.excludedAllergens = const <MealAllergen>{},
    this.priceGroup = MealPrice.studentGroup,
    this.favourites = const <String>{},
  });

  /// Properties a dish must have. **All** of them, not any: picking two
  /// narrows the list, it does not widen it.
  final Set<MealTrait> requiredTraits;

  /// Allergens that hide a dish.
  ///
  /// Excluding a parent facet covers its subtypes automatically, because the
  /// API delivers the parent alongside every subtype. Excluding one subtype on
  /// its own excludes exactly that subtype — a dish declared only as "contains
  /// gluten" is not evidence of wheat.
  final Set<MealAllergen> excludedAllergens;

  /// The one price group whose price is shown. Never null: a card shows exactly
  /// one price, and "student" is the group most readers of this app are in.
  final String priceGroup;

  /// Meal names the user starred. Keyed by **name**, not by id: the upstream id
  /// changes every time a dish is re-published, so an id-keyed favourite would
  /// silently stop matching the same dish next week.
  ///
  /// Favourites are not a filter and do not reorder anything. They are kept so
  /// the app can offer notifications for them later.
  final Set<String> favourites;

  static final CanteenFilter none = CanteenFilter();

  bool get isActive =>
      requiredTraits.isNotEmpty || excludedAllergens.isNotEmpty;

  bool isFavourite(Meal meal) => favourites.contains(meal.name);

  /// Whether [meal] survives the filter.
  bool allows(Meal meal) {
    if (meal.allergens.any(_expandedExcludedAllergens.contains)) {
      return false;
    }
    // `every` on an empty set is always true, but the argument is evaluated
    // first — so without this the widened trait set was built for every dish
    // on the counter even when nothing was required of it.
    if (requiredTraits.isEmpty) return true;
    return requiredTraits.every(effectiveTraits(meal.traits).contains);
  }

  /// [excludedAllergens] plus the subtypes of every excluded parent facet.
  ///
  /// Excluding a parent has to exclude a dish declared only by a subtype
  /// (and vice versa is already covered, since a subtype is excluded on its
  /// own) — the filter states this itself rather than trusting the source to
  /// always publish the parent alongside every subtype.
  ///
  /// Built once per filter, not once per dish: `allows` runs for every meal
  /// of the day and `apply` runs in the canteen screen's `build`, so the same
  /// widened set used to be assembled again for each of them. The filter is
  /// immutable, so one set is safe.
  late final Set<MealAllergen> _expandedExcludedAllergens = <MealAllergen>{
    ...excludedAllergens,
    for (final MealAllergen allergen in excludedAllergens)
      ...subtypesOf(allergen),
  };

  /// Whether [allergen] shows as excluded in the sheet: selected itself, or
  /// covered because its parent facet is fully excluded.
  bool isAllergenExcluded(MealAllergen allergen) {
    if (excludedAllergens.contains(allergen)) return true;
    final MealAllergen? parent = parentOf(allergen);
    return parent != null && excludedAllergens.contains(parent);
  }

  /// Whether every subtype of the parent facet [allergen] is excluded, either
  /// because the parent itself is selected or because all its subtypes are.
  bool isAllergenFullyExcluded(MealAllergen allergen) {
    if (excludedAllergens.contains(allergen)) return true;
    final List<MealAllergen> subtypes = subtypesOf(allergen);
    if (subtypes.isEmpty) return false;
    return subtypes.every(excludedAllergens.contains);
  }

  /// Whether the parent facet [allergen] has some but not all of its
  /// subtypes excluded — the "indeterminate" state the sheet must show
  /// distinctly from fully on or fully off.
  bool isAllergenPartiallyExcluded(MealAllergen allergen) {
    if (isAllergenFullyExcluded(allergen)) return false;
    return subtypesOf(allergen).any(excludedAllergens.contains);
  }

  /// Applies the filter, keeping the source's order.
  ///
  /// The counter order is the order the food is served in; re-sorting by
  /// favourites would make the list stop matching the board on the wall.
  List<Meal> apply(Iterable<Meal> meals) =>
      List<Meal>.unmodifiable(meals.where(allows));

  CanteenFilter toggleTrait(MealTrait trait) =>
      copyWith(requiredTraits: _toggled(requiredTraits, trait));

  /// Toggles [allergen], keeping the stored set an unambiguous, minimal
  /// description of what is shown as checked.
  ///
  /// Tapping a parent facet sets or clears the whole facet at once — a
  /// literal parent selection replaces any subtypes ticked individually,
  /// because the parent already covers them. Tapping a subtype while its
  /// parent is fully selected has to turn the parent selection into the
  /// remaining explicit subtypes; otherwise deselecting one subtype would
  /// have no visible effect while the parent still excludes it.
  CanteenFilter toggleAllergen(MealAllergen allergen) {
    final List<MealAllergen> subtypes = subtypesOf(allergen);
    if (subtypes.isNotEmpty) {
      final Set<MealAllergen> next = excludedAllergens.toSet()
        ..remove(allergen)
        ..removeAll(subtypes);
      if (!isAllergenFullyExcluded(allergen)) next.add(allergen);
      return copyWith(excludedAllergens: next);
    }

    final MealAllergen? parent = parentOf(allergen);
    if (parent != null && excludedAllergens.contains(parent)) {
      final Set<MealAllergen> next = excludedAllergens.toSet()
        ..remove(parent)
        ..addAll(
          subtypesOf(
            parent,
          ).where((MealAllergen subtype) => subtype != allergen),
        );
      return copyWith(excludedAllergens: next);
    }

    return copyWith(excludedAllergens: _toggled(excludedAllergens, allergen));
  }

  CanteenFilter toggleFavourite(Meal meal) =>
      copyWith(favourites: _toggled(favourites, meal.name));

  /// Removes [name] from the favourites, whether or not [Meal] carrying it is
  /// currently in any loaded menu — the favourites overview lets a dish be
  /// removed by name alone.
  CanteenFilter removeFavouriteNamed(String name) => copyWith(
    favourites: favourites.where((String other) => other != name).toSet(),
  );

  CanteenFilter withPriceGroup(String group) => copyWith(priceGroup: group);

  /// Clears the narrowing filters but keeps favourites and the price group —
  /// those are long-lived preferences, not a transient view.
  CanteenFilter cleared() =>
      CanteenFilter(priceGroup: priceGroup, favourites: favourites);

  CanteenFilter copyWith({
    Set<MealTrait>? requiredTraits,
    Set<MealAllergen>? excludedAllergens,
    String? priceGroup,
    Set<String>? favourites,
  }) => CanteenFilter(
    requiredTraits: requiredTraits ?? this.requiredTraits,
    excludedAllergens: excludedAllergens ?? this.excludedAllergens,
    priceGroup: priceGroup ?? this.priceGroup,
    favourites: favourites ?? this.favourites,
  );

  static Set<T> _toggled<T>(Set<T> set, T value) {
    final Set<T> next = set.toSet();
    if (!next.remove(value)) next.add(value);
    return next;
  }

  @override
  bool operator ==(Object other) =>
      other is CanteenFilter &&
      setEquals(other.requiredTraits, requiredTraits) &&
      setEquals(other.excludedAllergens, excludedAllergens) &&
      other.priceGroup == priceGroup &&
      setEquals(other.favourites, favourites);

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered(requiredTraits),
    Object.hashAllUnordered(excludedAllergens),
    priceGroup,
    Object.hashAllUnordered(favourites),
  );
}
