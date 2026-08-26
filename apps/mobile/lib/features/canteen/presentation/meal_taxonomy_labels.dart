// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import '../../../l10n/l10n.dart';
import '../domain/meal_taxonomy.dart';

/// The German and English wording of the fixed filter taxonomy.
///
/// Kept apart from the domain on purpose: the keys are a contract with the API
/// and must never depend on a language, while the wording is `gen_l10n` like
/// every other visible string in the app. The labels of the **source's** own
/// markers are a different thing entirely — those stay untranslated German and
/// are shown verbatim on the card.
String mealTraitLabel(AppLocalizations l10n, MealTrait trait) =>
    switch (trait) {
      MealTrait.vegetarian => l10n.canteenTraitVegetarian,
      MealTrait.vegan => l10n.canteenTraitVegan,
      MealTrait.meatless => l10n.canteenTraitMeatless,
      MealTrait.sprint => l10n.canteenTraitSprint,
    };

String mealAllergenLabel(AppLocalizations l10n, MealAllergen allergen) =>
    switch (allergen) {
      MealAllergen.gluten => l10n.canteenAllergenGluten,
      MealAllergen.glutenWheat => l10n.canteenAllergenGlutenWheat,
      MealAllergen.glutenRye => l10n.canteenAllergenGlutenRye,
      MealAllergen.glutenOats => l10n.canteenAllergenGlutenOats,
      MealAllergen.glutenBarley => l10n.canteenAllergenGlutenBarley,
      MealAllergen.glutenSpelt => l10n.canteenAllergenGlutenSpelt,
      MealAllergen.crustaceans => l10n.canteenAllergenCrustaceans,
      MealAllergen.egg => l10n.canteenAllergenEgg,
      MealAllergen.peanuts => l10n.canteenAllergenPeanuts,
      MealAllergen.soy => l10n.canteenAllergenSoy,
      MealAllergen.milk => l10n.canteenAllergenMilk,
      MealAllergen.nuts => l10n.canteenAllergenNuts,
      MealAllergen.nutsHazelnut => l10n.canteenAllergenNutsHazelnut,
      MealAllergen.nutsAlmond => l10n.canteenAllergenNutsAlmond,
      MealAllergen.nutsWalnut => l10n.canteenAllergenNutsWalnut,
      MealAllergen.nutsCashew => l10n.canteenAllergenNutsCashew,
      MealAllergen.nutsPecan => l10n.canteenAllergenNutsPecan,
      MealAllergen.nutsPistachio => l10n.canteenAllergenNutsPistachio,
      MealAllergen.nutsMacadamia => l10n.canteenAllergenNutsMacadamia,
      MealAllergen.celery => l10n.canteenAllergenCelery,
      MealAllergen.mustard => l10n.canteenAllergenMustard,
      MealAllergen.sesame => l10n.canteenAllergenSesame,
      MealAllergen.sulphites => l10n.canteenAllergenSulphites,
      MealAllergen.lupin => l10n.canteenAllergenLupin,
      MealAllergen.molluscs => l10n.canteenAllergenMolluscs,
      MealAllergen.fish => l10n.canteenAllergenFish,
    };
