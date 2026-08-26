// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:campus_koethen/features/canteen/data/canteen_models.dart';
import 'package:campus_koethen/features/canteen/domain/canteen_filter.dart';
import 'package:campus_koethen/features/canteen/domain/meal_taxonomy.dart';
import 'package:flutter_test/flutter_test.dart';

Meal _meal(
  String name, {
  Set<MealTrait> traits = const <MealTrait>{},
  Set<MealAllergen> allergens = const <MealAllergen>{},
  List<MealPrice> prices = const <MealPrice>[],
}) => Meal(
  id: 'id-$name',
  name: name,
  traits: traits,
  allergens: allergens,
  prices: prices,
);

void main() {
  group('must contain', () {
    test('an unfiltered list is untouched', () {
      final List<Meal> meals = <Meal>[_meal('a'), _meal('b')];
      expect(CanteenFilter.none.apply(meals).length, 2);
      expect(CanteenFilter.none.isActive, isFalse);
    });

    test('a required trait narrows the list', () {
      final List<Meal> meals = <Meal>[
        _meal('Gemüsepfanne', traits: <MealTrait>{MealTrait.vegan}),
        _meal('Gulasch'),
      ];
      final CanteenFilter filter = CanteenFilter.none.toggleTrait(
        MealTrait.vegan,
      );

      expect(filter.apply(meals).map((Meal m) => m.name), <String>[
        'Gemüsepfanne',
      ]);
      expect(filter.isActive, isTrue);
    });

    test('two required traits mean both, not either', () {
      final List<Meal> meals = <Meal>[
        _meal('both', traits: <MealTrait>{MealTrait.vegan, MealTrait.sprint}),
        _meal('only one', traits: <MealTrait>{MealTrait.vegan}),
      ];
      final CanteenFilter filter = CanteenFilter.none
          .toggleTrait(MealTrait.vegan)
          .toggleTrait(MealTrait.sprint);

      expect(filter.apply(meals).map((Meal m) => m.name), <String>['both']);
    });

    test('toggling twice returns to the start', () {
      final CanteenFilter filter = CanteenFilter.none
          .toggleTrait(MealTrait.vegan)
          .toggleTrait(MealTrait.vegan);
      expect(filter.requiredTraits, isEmpty);
      expect(filter.isActive, isFalse);
    });

    test('vegetarian also shows vegan dishes, even if not double-tagged', () {
      // A vegan dish is vegetarian by definition; the source is not
      // guaranteed to state both traits on every dish.
      final List<Meal> meals = <Meal>[
        _meal('Linsensuppe', traits: <MealTrait>{MealTrait.vegetarian}),
        _meal('Falafel', traits: <MealTrait>{MealTrait.vegan}),
        _meal('Gulasch'),
      ];
      final CanteenFilter filter = CanteenFilter.none.toggleTrait(
        MealTrait.vegetarian,
      );

      expect(filter.apply(meals).map((Meal m) => m.name), <String>[
        'Linsensuppe',
        'Falafel',
      ]);
    });

    test('vegan alone still excludes a merely vegetarian dish', () {
      final List<Meal> meals = <Meal>[
        _meal('Linsensuppe', traits: <MealTrait>{MealTrait.vegetarian}),
        _meal('Falafel', traits: <MealTrait>{MealTrait.vegan}),
      ];
      final CanteenFilter filter = CanteenFilter.none.toggleTrait(
        MealTrait.vegan,
      );

      expect(filter.apply(meals).map((Meal m) => m.name), <String>['Falafel']);
    });
  });

  group('must not contain', () {
    test('an excluded allergen hides the dish', () {
      final List<Meal> meals = <Meal>[
        _meal('Nussecke', allergens: <MealAllergen>{MealAllergen.nuts}),
        _meal('Pasta'),
      ];
      final CanteenFilter filter = CanteenFilter.none.toggleAllergen(
        MealAllergen.nuts,
      );

      expect(filter.apply(meals).map((Meal m) => m.name), <String>['Pasta']);
    });

    test('excluding the parent facet also excludes its subtypes', () {
      // Somebody avoiding gluten must not have to tick five cereals — and the
      // dish only ever declares the cereal, not the word "gluten".
      final List<Meal> meals = <Meal>[
        _meal(
          'Nudeln',
          allergens: <MealAllergen>{
            MealAllergen.gluten,
            MealAllergen.glutenWheat,
          },
        ),
        _meal('Reis'),
      ];
      final CanteenFilter filter = CanteenFilter.none.toggleAllergen(
        MealAllergen.gluten,
      );

      expect(filter.apply(meals).map((Meal m) => m.name), <String>['Reis']);
    });

    test('excluding one subtype excludes only that subtype', () {
      final List<Meal> meals = <Meal>[
        _meal(
          'Weizennudeln',
          allergens: <MealAllergen>{
            MealAllergen.gluten,
            MealAllergen.glutenWheat,
          },
        ),
        _meal(
          'Haferbrei',
          allergens: <MealAllergen>{
            MealAllergen.gluten,
            MealAllergen.glutenOats,
          },
        ),
      ];
      final CanteenFilter filter = CanteenFilter.none.toggleAllergen(
        MealAllergen.glutenWheat,
      );

      expect(filter.apply(meals).map((Meal m) => m.name), <String>[
        'Haferbrei',
      ]);
    });

    test('a dish declared only as the parent survives a subtype filter', () {
      // "Contains gluten" is not evidence of wheat, and guessing on food is
      // exactly what this taxonomy exists to avoid.
      final List<Meal> meals = <Meal>[
        _meal('Gebäck', allergens: <MealAllergen>{MealAllergen.gluten}),
      ];
      final CanteenFilter filter = CanteenFilter.none.toggleAllergen(
        MealAllergen.glutenWheat,
      );

      expect(filter.apply(meals), hasLength(1));
    });

    test('excluding the parent also hides a dish declared only by subtype, '
        'without the parent tag', () {
      // The filter must not rely on the source always publishing the
      // parent alongside every subtype it declares.
      final List<Meal> meals = <Meal>[
        _meal('Haferkekse', allergens: <MealAllergen>{MealAllergen.glutenOats}),
        _meal('Reis'),
      ];
      final CanteenFilter filter = CanteenFilter.none.toggleAllergen(
        MealAllergen.gluten,
      );

      expect(filter.apply(meals).map((Meal m) => m.name), <String>['Reis']);
    });

    test('selecting the parent visibly checks every subtype', () {
      final CanteenFilter filter = CanteenFilter.none.toggleAllergen(
        MealAllergen.gluten,
      );

      expect(filter.isAllergenFullyExcluded(MealAllergen.gluten), isTrue);
      for (final MealAllergen subtype in subtypesOf(MealAllergen.gluten)) {
        expect(filter.isAllergenExcluded(subtype), isTrue);
      }
    });

    test('deselecting the parent clears every subtype too', () {
      final CanteenFilter filter = CanteenFilter.none
          .toggleAllergen(MealAllergen.gluten)
          .toggleAllergen(MealAllergen.gluten);

      expect(filter.excludedAllergens, isEmpty);
      for (final MealAllergen subtype in subtypesOf(MealAllergen.gluten)) {
        expect(filter.isAllergenExcluded(subtype), isFalse);
      }
    });

    test('selecting some subtypes shows the parent as partial, not off', () {
      final CanteenFilter filter = CanteenFilter.none.toggleAllergen(
        MealAllergen.glutenWheat,
      );

      expect(filter.isAllergenFullyExcluded(MealAllergen.gluten), isFalse);
      expect(filter.isAllergenPartiallyExcluded(MealAllergen.gluten), isTrue);
    });

    test('deselecting one subtype while the parent is selected keeps the '
        'others excluded and shows the parent as partial', () {
      final CanteenFilter selected = CanteenFilter.none.toggleAllergen(
        MealAllergen.gluten,
      );
      final CanteenFilter afterUntick = selected.toggleAllergen(
        MealAllergen.glutenWheat,
      );

      expect(afterUntick.isAllergenExcluded(MealAllergen.glutenWheat), isFalse);
      expect(afterUntick.isAllergenExcluded(MealAllergen.glutenRye), isTrue);
      expect(
        afterUntick.isAllergenPartiallyExcluded(MealAllergen.gluten),
        isTrue,
      );
      expect(afterUntick.isAllergenFullyExcluded(MealAllergen.gluten), isFalse);

      final List<Meal> meals = <Meal>[
        _meal(
          'Weizenbrot',
          allergens: <MealAllergen>{MealAllergen.glutenWheat},
        ),
        _meal('Roggenbrot', allergens: <MealAllergen>{MealAllergen.glutenRye}),
      ];
      expect(afterUntick.apply(meals).map((Meal m) => m.name), <String>[
        'Weizenbrot',
      ]);
    });

    test('selecting every subtype individually reads as fully excluded', () {
      CanteenFilter filter = CanteenFilter.none;
      for (final MealAllergen subtype in subtypesOf(MealAllergen.gluten)) {
        filter = filter.toggleAllergen(subtype);
      }

      expect(filter.isAllergenFullyExcluded(MealAllergen.gluten), isTrue);
      expect(filter.isAllergenPartiallyExcluded(MealAllergen.gluten), isFalse);
    });

    test('required and excluded work together', () {
      final List<Meal> meals = <Meal>[
        _meal(
          'veganer Nusskuchen',
          traits: <MealTrait>{MealTrait.vegan},
          allergens: <MealAllergen>{MealAllergen.nuts},
        ),
        _meal('veganer Salat', traits: <MealTrait>{MealTrait.vegan}),
        _meal('Schnitzel'),
      ];
      final CanteenFilter filter = CanteenFilter.none
          .toggleTrait(MealTrait.vegan)
          .toggleAllergen(MealAllergen.nuts);

      expect(filter.apply(meals).map((Meal m) => m.name), <String>[
        'veganer Salat',
      ]);
    });
  });

  group('favourites', () {
    test('are keyed by name, not by the upstream id', () {
      // The source re-publishes the same dish with a new id every week; an
      // id-keyed favourite would quietly stop matching it.
      final CanteenFilter filter = CanteenFilter.none.toggleFavourite(
        _meal('Gemüsepfanne'),
      );
      final Meal sameDishNextWeek = Meal(
        id: 'a-completely-different-id',
        name: 'Gemüsepfanne',
      );
      expect(filter.isFavourite(sameDishNextWeek), isTrue);
    });

    test('do not filter anything', () {
      final List<Meal> meals = <Meal>[_meal('a'), _meal('b')];
      final CanteenFilter filter = CanteenFilter.none.toggleFavourite(
        _meal('a'),
      );
      expect(filter.apply(meals), hasLength(2));
      expect(filter.isActive, isFalse);
    });

    test('do not change the order', () {
      // The counter order is the order the food is served in; re-sorting would
      // make the list stop matching the board on the wall.
      final List<Meal> meals = <Meal>[_meal('a'), _meal('b'), _meal('c')];
      final CanteenFilter filter = CanteenFilter.none.toggleFavourite(
        _meal('c'),
      );
      expect(filter.apply(meals).map((Meal m) => m.name), <String>[
        'a',
        'b',
        'c',
      ]);
    });
  });

  group('clearing', () {
    test('keeps favourites and the price group', () {
      // Those are long-lived preferences, not a transient view.
      final CanteenFilter filter = CanteenFilter.none
          .toggleTrait(MealTrait.vegan)
          .toggleAllergen(MealAllergen.nuts)
          .toggleFavourite(_meal('Pasta'))
          .withPriceGroup('employee');

      final CanteenFilter cleared = filter.cleared();
      expect(cleared.requiredTraits, isEmpty);
      expect(cleared.excludedAllergens, isEmpty);
      expect(cleared.isFavourite(_meal('Pasta')), isTrue);
      expect(cleared.priceGroup, 'employee');
    });
  });

  group('price group', () {
    test('is the student group by default', () {
      expect(CanteenFilter.none.priceGroup, 'student');
    });

    test('can be changed', () {
      expect(
        CanteenFilter.none.withPriceGroup('employee').priceGroup,
        'employee',
      );
    });

    test('does not filter anything out', () {
      final List<Meal> meals = <Meal>[_meal('a')];
      expect(CanteenFilter.none.withPriceGroup('guest').apply(meals).length, 1);
    });
  });

  group('the meal price of one group', () {
    const MealPrice student = MealPrice(
      group: 'student',
      label: 'Studierende',
      amount: '1.95',
      currency: 'EUR',
    );
    const MealPrice guest = MealPrice(
      group: 'guest',
      label: 'Gäste',
      amount: '7.00',
      currency: 'EUR',
    );

    test('is found by its stable key', () {
      final Meal meal = _meal('a', prices: <MealPrice>[student, guest]);
      expect(meal.priceFor('guest')?.amount, '7.00');
    });

    test('is null when the source did not deliver it', () {
      // Never another group's price: that is a different number for a
      // different person.
      final Meal meal = _meal('a', prices: <MealPrice>[student]);
      expect(meal.priceFor('employee'), isNull);
    });
  });

  group('next open day', _nextOpenDayTests);
}

void _nextOpenDayTests() {
  CanteenMenu menu(List<MenuDay> days) =>
      CanteenMenu(canteenSlug: 's', displayName: 'M', days: days);
  MenuDay day(int d, {bool open = true}) => MenuDay(
    date: DateTime(2026, 5, d),
    meals: open ? <Meal>[Meal(id: '$d', name: 'Gericht $d')] : const <Meal>[],
  );

  test('finds the next day that actually has an offer', () {
    // Closed at the weekend: the answer is Monday, not "nothing".
    final CanteenMenu m = menu(<MenuDay>[
      day(15),
      day(16, open: false),
      day(17, open: false),
      day(18),
    ]);
    expect(
      m.nextOpenDayFrom(DateTime(2026, 5, 16))?.date,
      DateTime(2026, 5, 18),
    );
  });

  test('today counts when today is open', () {
    final CanteenMenu m = menu(<MenuDay>[day(15), day(18)]);
    expect(
      m.nextOpenDayFrom(DateTime(2026, 5, 15))?.date,
      DateTime(2026, 5, 15),
    );
  });

  test('never looks backwards', () {
    final CanteenMenu m = menu(<MenuDay>[day(10), day(11)]);
    expect(m.nextOpenDayFrom(DateTime(2026, 5, 20)), isNull);
  });

  test('an entirely closed window has no answer, and that is fine', () {
    final CanteenMenu m = menu(<MenuDay>[day(15, open: false)]);
    expect(m.nextOpenDayFrom(DateTime(2026, 5, 15)), isNull);
  });

  group('repeated filtering', () {
    test('the widened exclusion set gives the same answer every time', () {
      // `apply` runs in the canteen screen's build and `allows` runs once per
      // dish, so the widened set is now built once per filter instead of once
      // per dish. Every call has to keep agreeing.
      final CanteenFilter filter = CanteenFilter.none.toggleAllergen(
        MealAllergen.gluten,
      );
      final List<Meal> meals = <Meal>[
        _meal('Nudeln', allergens: <MealAllergen>{MealAllergen.glutenWheat}),
        _meal('Salat'),
        _meal('Brot', allergens: <MealAllergen>{MealAllergen.gluten}),
      ];

      final List<String> first = filter
          .apply(meals)
          .map((Meal m) => m.name)
          .toList();
      final List<String> second = filter
          .apply(meals)
          .map((Meal m) => m.name)
          .toList();

      expect(first, <String>['Salat']);
      expect(second, first);
      // And per-dish, in both orders.
      expect(filter.allows(meals[0]), isFalse);
      expect(filter.allows(meals[1]), isTrue);
      expect(filter.allows(meals[0]), isFalse);
    });

    test('with nothing required every dish still passes the trait check', () {
      final CanteenFilter filter = CanteenFilter.none.toggleAllergen(
        MealAllergen.egg,
      );
      final Meal meal = _meal(
        'Gemüsepfanne',
        traits: <MealTrait>{MealTrait.vegan},
      );
      expect(filter.allows(meal), isTrue);
      expect(CanteenFilter.none.allows(meal), isTrue);
    });
  });
}
