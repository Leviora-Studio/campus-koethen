// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

/// Tapping a meal's price opens an overview of every price group — never
/// inventing a group the API did not deliver.
library;

import 'package:campus_koethen/core/widgets/sheet_body.dart';
import 'package:campus_koethen/features/canteen/data/canteen_models.dart';
import 'package:campus_koethen/features/canteen/presentation/meal_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/pump_app.dart';

/// Scopes a finder to the price overview sheet, so the meal card underneath
/// it — still mounted, only covered — cannot produce a false match on the
/// same group label.
Finder _inSheet(Finder matching) =>
    find.descendant(of: find.byType(SheetBody), matching: matching);

const List<MealPrice> _allGroups = <MealPrice>[
  MealPrice(
    group: 'student',
    label: 'Studierende',
    amount: '3.20',
    currency: 'EUR',
  ),
  MealPrice(
    group: 'employee',
    label: 'Mitarbeitende',
    amount: '4.10',
    currency: 'EUR',
  ),
  MealPrice(group: 'guest', label: 'Gäste', amount: '5.50', currency: 'EUR'),
];

Meal _meal(List<MealPrice> prices) =>
    Meal(id: '58033', name: 'Bulgur-Pfanne', prices: prices);

/// Enables the semantics tree, pumps the card and taps it open.
///
/// Returns the [SemanticsHandle] for the caller to dispose after its
/// assertions: disposing earlier (e.g. via `addTearDown`) runs too late for
/// flutter_test's own end-of-test check, since `addTearDown` callbacks fire
/// after the `testWidgets` body has already returned.
Future<SemanticsHandle> _pumpAndOpen(
  WidgetTester tester,
  Meal meal, {
  List<MealPrice> knownPriceGroups = _allGroups,
}) async {
  final SemanticsHandle handle = tester.ensureSemantics();

  await pumpScreen(
    tester,
    Scaffold(
      body: ListView(
        children: <Widget>[
          MealCard(
            meal: meal,
            priceGroup: 'student',
            knownPriceGroups: knownPriceGroups,
          ),
        ],
      ),
    ),
  );
  await tester.pumpAndSettle();

  await tester.tap(find.bySemanticsLabel(RegExp('Preise für Bulgur-Pfanne')));
  await tester.pumpAndSettle();

  return handle;
}

void main() {
  testWidgets('shows all three price groups when the meal has all of them', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = await _pumpAndOpen(
      tester,
      _meal(_allGroups),
    );

    expect(_inSheet(find.text('Studierende')), findsOneWidget);
    expect(_inSheet(find.text('Mitarbeitende')), findsOneWidget);
    expect(_inSheet(find.text('Gäste')), findsOneWidget);
    expect(_inSheet(find.textContaining('3,20')), findsOneWidget);
    expect(_inSheet(find.textContaining('4,10')), findsOneWidget);
    expect(_inSheet(find.textContaining('5,50')), findsOneWidget);

    handle.dispose();
  });

  testWidgets(
    'marks a group missing on this meal as unavailable, never as 0,00 €',
    (WidgetTester tester) async {
      final SemanticsHandle handle = await _pumpAndOpen(
        tester,
        _meal(<MealPrice>[_allGroups[0], _allGroups[1]]),
      );

      expect(_inSheet(find.text('Studierende')), findsOneWidget);
      expect(_inSheet(find.text('Mitarbeitende')), findsOneWidget);
      expect(_inSheet(find.text('Gäste')), findsOneWidget);
      expect(_inSheet(find.textContaining('0,00')), findsNothing);
      expect(_inSheet(find.text('nicht verfügbar')), findsOneWidget);

      handle.dispose();
    },
  );

  testWidgets('states every group as unavailable when the meal has none', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = await _pumpAndOpen(
      tester,
      _meal(const <MealPrice>[]),
    );

    expect(_inSheet(find.text('Studierende')), findsOneWidget);
    expect(_inSheet(find.text('Mitarbeitende')), findsOneWidget);
    expect(_inSheet(find.text('Gäste')), findsOneWidget);
    expect(_inSheet(find.text('nicht verfügbar')), findsNWidgets(3));
    expect(_inSheet(find.textContaining('0,00')), findsNothing);

    handle.dispose();
  });

  testWidgets('opening the overview does not change the selected group', (
    WidgetTester tester,
  ) async {
    final SemanticsHandle handle = await _pumpAndOpen(
      tester,
      _meal(_allGroups),
    );

    // The selected group is marked, not switched — a bare tap that opens the
    // sheet must never write a new preference by itself.
    expect(
      find.bySemanticsLabel(RegExp('Ausgewählt.*Studierende: 3,20')),
      findsOneWidget,
    );

    handle.dispose();
  });
}
