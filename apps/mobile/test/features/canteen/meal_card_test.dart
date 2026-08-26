// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

/// What a meal card puts on screen — and what it deliberately does not.
library;

import 'package:campus_koethen/features/canteen/data/canteen_models.dart';
import 'package:campus_koethen/features/canteen/presentation/meal_card.dart';
import 'package:campus_koethen/core/theme/app_colors.dart';
import 'package:campus_koethen/core/theme/app_dimensions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/pump_app.dart';

Meal _meal() => const Meal(
  id: '58033',
  name: 'Bulgur-Pfanne',
  subtitle: 'mit Kichererbsen',
  extras: <String>['Salatbeilage'],
  markers: <MealMarker>[
    MealMarker(code: '52', label: 'vegan', kind: 'ingredient'),
    MealMarker(code: '20', label: 'Weizen', kind: 'ingredient'),
    MealMarker(code: '99', label: 'Klima-Teller', kind: 'marker'),
  ],
  prices: <MealPrice>[
    MealPrice(
      group: 'student',
      label: 'Studierende',
      amount: '3.20',
      currency: 'EUR',
    ),
  ],
);

Future<void> _pump(
  WidgetTester tester, {
  ThemeMode themeMode = ThemeMode.light,
}) async {
  await pumpScreen(
    tester,
    Scaffold(
      body: ListView(
        children: <Widget>[MealCard(meal: _meal(), priceGroup: 'student')],
      ),
    ),
    themeMode: themeMode,
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('does not list the ingredients on the dish', (
    WidgetTester tester,
  ) async {
    // The ingredient declarations are what the filter is for. Repeating all of
    // them under every dish buried the two lines that actually differ between
    // one meal and the next.
    await _pump(tester);

    expect(find.text('vegan'), findsNothing);
    expect(find.text('Weizen'), findsNothing);
    expect(find.text('Zutaten'), findsNothing);
  });

  testWidgets('still shows the markers no filter covers', (
    WidgetTester tester,
  ) async {
    // Bio, Klima-Teller and the like are statements about the dish, not
    // ingredient declarations — nothing else on the screen says them.
    await _pump(tester);

    expect(find.text('Klima-Teller'), findsOneWidget);
  });

  testWidgets('keeps name, extras and the chosen price', (
    WidgetTester tester,
  ) async {
    await _pump(tester);

    expect(find.text('Bulgur-Pfanne'), findsOneWidget);
    expect(find.text('Salatbeilage'), findsOneWidget);
    expect(find.text('Studierende'), findsOneWidget);
    expect(find.textContaining('3,20'), findsOneWidget);
  });

  testWidgets('uses the supplied price colours in light and dark mode', (
    WidgetTester tester,
  ) async {
    for (final (ThemeMode mode, Color expected) in <(ThemeMode, Color)>[
      (ThemeMode.light, AppColors.light.primaryDark),
      (ThemeMode.dark, AppColors.dark.primary),
    ]) {
      await _pump(tester, themeMode: mode);
      final Text price = tester.widget<Text>(find.textContaining('3,20'));
      expect(price.style?.color, expected);
    }
  });

  testWidgets('renders meal badges as rounded rectangles instead of pills', (
    WidgetTester tester,
  ) async {
    await _pump(tester);

    final Chip chip = tester.widget<Chip>(
      find.ancestor(of: find.text('Klima-Teller'), matching: find.byType(Chip)),
    );
    final RoundedRectangleBorder shape = chip.shape! as RoundedRectangleBorder;
    expect(shape.borderRadius, BorderRadius.circular(AppRadius.badge));
  });
}
