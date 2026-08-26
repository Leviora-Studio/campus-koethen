// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

/// The tap target of the 11:00 canteen hint: the dish the reader tapped, and
/// what happens when it is no longer there.
library;

import 'package:campus_koethen/core/locale/locale_mode.dart';
import 'package:campus_koethen/core/prefs/key_value_store.dart';
import 'package:campus_koethen/core/prefs/settings_controller.dart';
import 'package:campus_koethen/features/canteen/application/canteen_providers.dart';
import 'package:campus_koethen/features/canteen/data/canteen_models.dart';
import 'package:campus_koethen/features/canteen/domain/meal_highlight.dart';
import 'package:campus_koethen/features/canteen/presentation/meal_card.dart';
import 'package:campus_koethen/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../../support/pump_app.dart';

Meal _meal() => const Meal(
  id: '58033',
  name: 'Käsespätzle',
  prices: <MealPrice>[
    MealPrice(
      group: 'student',
      label: 'Studierende',
      amount: '2.80',
      currency: 'EUR',
    ),
  ],
);

void main() {
  late AppLocalizations de;

  setUpAll(() async {
    de = await AppLocalizations.delegate.load(AppLocales.german);
  });

  group('the highlight only applies where it means something', () {
    final MealHighlight highlight = MealHighlight(
      canteenSlug: 'fasanerieallee',
      day: DateTime(2026, 9, 3),
      mealName: 'Käsespätzle',
    );

    test('marks its own dish on its own day in its own canteen', () {
      expect(
        highlight.marks(
          slug: 'fasanerieallee',
          shownDay: DateTime(2026, 9, 3),
          name: 'Käsespätzle',
        ),
        isTrue,
      );
    });

    test('marks nothing on another day, canteen or dish', () {
      expect(
        highlight.marks(
          slug: 'fasanerieallee',
          shownDay: DateTime(2026, 9, 4),
          name: 'Käsespätzle',
        ),
        isFalse,
      );
      expect(
        highlight.marks(
          slug: 'am-tierpark',
          shownDay: DateTime(2026, 9, 3),
          name: 'Käsespätzle',
        ),
        isFalse,
      );
      expect(
        highlight.marks(
          slug: 'fasanerieallee',
          shownDay: DateTime(2026, 9, 3),
          name: 'Linsen',
        ),
        isFalse,
      );
    });
  });

  test('moving to another day drops the highlight', () {
    final ProviderContainer container = ProviderContainer(
      overrides: <Override>[
        keyValueStoreProvider.overrideWithValue(InMemoryKeyValueStore()),
      ],
    );
    addTearDown(container.dispose);
    // Listened to, so the controller is alive — an unread provider has no
    // state to lose and the test would pass for the wrong reason.
    container.listen<MealHighlight?>(
      mealHighlightProvider,
      (_, _) {},
      fireImmediately: true,
    );

    container
        .read(selectedMenuDayProvider.notifier)
        .select(DateTime(2026, 9, 3));
    container
        .read(mealHighlightProvider.notifier)
        .mark(
          MealHighlight(
            canteenSlug: 'fasanerieallee',
            day: DateTime(2026, 9, 3),
            mealName: 'Käsespätzle',
          ),
        );
    expect(container.read(mealHighlightProvider), isNotNull);

    container.read(selectedMenuDayProvider.notifier).shiftBy(1);

    expect(container.read(mealHighlightProvider), isNull);
  });

  testWidgets('a highlighted card says so in words, not in colour alone', (
    WidgetTester tester,
  ) async {
    await pumpScreen(
      tester,
      Scaffold(
        body: ListView(
          children: <Widget>[
            MealCard(meal: _meal(), priceGroup: 'student', isHighlighted: true),
          ],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(de.canteenHighlightedByNotification), findsOneWidget);
  });

  testWidgets('an ordinary card carries no such marker', (
    WidgetTester tester,
  ) async {
    await pumpScreen(
      tester,
      Scaffold(
        body: ListView(
          children: <Widget>[MealCard(meal: _meal(), priceGroup: 'student')],
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(de.canteenHighlightedByNotification), findsNothing);
  });
}
