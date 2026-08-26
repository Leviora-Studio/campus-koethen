// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

// The fixed vocabulary the canteen filter offers.
//
// These are the **API's** stable semantic keys, not the source's marker codes.
// The source publishes an undocumented namespace of its own (`A1`, `G!`, `52`)
// that mixes two dictionaries and can be renumbered at any time; the Campus API
// maps it once, centrally and under test, and delivers `traits` and
// `allergens`. Filtering on a code or on a German label here would mean
// hardcoding a foreign key list and hoping it never changes — on food, where
// somebody avoiding peanuts is trusting the answer.
//
// The list is deliberately **fixed**, not derived from the visible day: a
// filter that appears and disappears with the day's offer is impossible to
// rely on, and "no gluten" has to mean the same thing on a Tuesday as on a
// Friday.

/// What a dish *is*. Selected under "must contain".
enum MealTrait {
  vegetarian('vegetarian'),
  vegan('vegan'),
  meatless('meatless'),
  sprint('sprint');

  const MealTrait(this.key);

  /// Wire and storage key. Never shown to the user.
  final String key;

  static MealTrait? fromKey(String key) {
    for (final MealTrait trait in MealTrait.values) {
      if (trait.key == key) return trait;
    }
    return null;
  }
}

/// What a dish *contains*. Selected under "must not contain".
///
/// Order is the published taxonomy: every parent is immediately followed by its
/// subtypes.
enum MealAllergen {
  gluten('gluten'),
  glutenWheat('gluten_wheat'),
  glutenRye('gluten_rye'),
  glutenOats('gluten_oats'),
  glutenBarley('gluten_barley'),
  glutenSpelt('gluten_spelt'),
  crustaceans('crustaceans'),
  egg('egg'),
  peanuts('peanuts'),
  soy('soy'),
  milk('milk'),
  nuts('nuts'),
  nutsHazelnut('nuts_hazelnut'),
  nutsAlmond('nuts_almond'),
  nutsWalnut('nuts_walnut'),
  nutsCashew('nuts_cashew'),
  nutsPecan('nuts_pecan'),
  nutsPistachio('nuts_pistachio'),
  nutsMacadamia('nuts_macadamia'),
  celery('celery'),
  mustard('mustard'),
  sesame('sesame'),
  sulphites('sulphites'),
  lupin('lupin'),
  molluscs('molluscs'),
  fish('fish');

  const MealAllergen(this.key);

  final String key;

  static MealAllergen? fromKey(String key) {
    for (final MealAllergen allergen in MealAllergen.values) {
      if (allergen.key == key) return allergen;
    }
    return null;
  }
}

/// A narrower trait implies the wider one it is a special case of.
///
/// A vegan dish is vegetarian by definition, but the source is not guaranteed
/// to double-tag every dish with both — filtering must know the relation
/// itself rather than assume the API always states both.
const Map<MealTrait, MealTrait> kTraitImplies = <MealTrait, MealTrait>{
  MealTrait.vegan: MealTrait.vegetarian,
};

/// [traits] plus every trait implied by one already in it.
Set<MealTrait> effectiveTraits(Set<MealTrait> traits) {
  final Set<MealTrait> effective = traits.toSet();
  for (final MealTrait trait in traits) {
    final MealTrait? wider = kTraitImplies[trait];
    if (wider != null) effective.add(wider);
  }
  return effective;
}

/// The two hierarchical facets, parent to subtypes.
///
/// The API always delivers the parent alongside a subtype, so excluding
/// "gluten" already excludes a dish declared as wheat. This map exists for the
/// **user interface**: it is what lets the sheet show the subtypes underneath
/// their parent instead of as twenty-six equal siblings.
const Map<MealAllergen, List<MealAllergen>> kAllergenSubtypes =
    <MealAllergen, List<MealAllergen>>{
      MealAllergen.gluten: <MealAllergen>[
        MealAllergen.glutenWheat,
        MealAllergen.glutenRye,
        MealAllergen.glutenOats,
        MealAllergen.glutenBarley,
        MealAllergen.glutenSpelt,
      ],
      MealAllergen.nuts: <MealAllergen>[
        MealAllergen.nutsHazelnut,
        MealAllergen.nutsAlmond,
        MealAllergen.nutsWalnut,
        MealAllergen.nutsCashew,
        MealAllergen.nutsPecan,
        MealAllergen.nutsPistachio,
        MealAllergen.nutsMacadamia,
      ],
    };

/// Every allergen that is not a subtype of another, in taxonomy order.
List<MealAllergen> get allergenTopLevel {
  final Set<MealAllergen> subtypes = <MealAllergen>{
    for (final List<MealAllergen> children in kAllergenSubtypes.values)
      ...children,
  };
  return MealAllergen.values
      .where((MealAllergen allergen) => !subtypes.contains(allergen))
      .toList(growable: false);
}

/// The subtypes of [allergen], or an empty list for a leaf.
List<MealAllergen> subtypesOf(MealAllergen allergen) =>
    kAllergenSubtypes[allergen] ?? const <MealAllergen>[];

/// The parent facet of [allergen], or `null` when it is not a subtype of one.
MealAllergen? parentOf(MealAllergen allergen) {
  for (final MapEntry<MealAllergen, List<MealAllergen>> entry
      in kAllergenSubtypes.entries) {
    if (entry.value.contains(allergen)) return entry.key;
  }
  return null;
}
