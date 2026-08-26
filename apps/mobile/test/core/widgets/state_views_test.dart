// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:campus_koethen/core/widgets/state_views.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/pump_app.dart';

void main() {
  group('state views under a cramped, bounded height', () {
    // The smallest supported Android viewport with a keyboard tall enough to
    // leave almost nothing for the region a loading/empty/error state sits
    // in — the constellation that first surfaced the bug: any screen that
    // hands one of these views an `Expanded` region shrunk by a large
    // Android keyboard threw a `RenderFlex overflowed` error instead of
    // simply looking cramped.
    Future<void> pumpCramped(WidgetTester tester, Widget child) async {
      tester.view.physicalSize = const Size(320, 480);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 400);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetViewInsets);

      await pumpScreen(
        tester,
        Scaffold(
          resizeToAvoidBottomInset: false,
          body: Column(
            children: <Widget>[
              Expanded(
                child: Builder(
                  builder: (BuildContext context) => Padding(
                    padding: EdgeInsets.only(
                      bottom: MediaQuery.viewInsetsOf(context).bottom,
                    ),
                    child: child,
                  ),
                ),
              ),
            ],
          ),
        ),
        textScaler: const TextScaler.linear(2),
      );
    }

    testWidgets('LoadingView does not overflow', (WidgetTester tester) async {
      await pumpCramped(tester, const LoadingView());
      expect(tester.takeException(), isNull);
    });

    testWidgets('EmptyView with an action does not overflow', (
      WidgetTester tester,
    ) async {
      await pumpCramped(
        tester,
        EmptyView(
          title: 'Nichts hier',
          message: 'Es gibt aktuell nichts anzuzeigen.',
          action: FilledButton(onPressed: () {}, child: const Text('Aktion')),
        ),
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('ErrorView with its retry button does not overflow', (
      WidgetTester tester,
    ) async {
      await pumpCramped(tester, ErrorView(onRetry: () {}));
      expect(tester.takeException(), isNull);
    });
  });

  group('state views under an unbounded height', () {
    // Some screens place these views inside a plain, non-flex-fill scroll
    // ancestor rather than an `Expanded` region — the centering must keep
    // working there exactly as before, without an invalid-constraint crash.
    testWidgets('LoadingView still centers without a bounded parent', (
      WidgetTester tester,
    ) async {
      await pumpScreen(
        tester,
        const Scaffold(body: SingleChildScrollView(child: LoadingView())),
      );
      expect(tester.takeException(), isNull);
      expect(find.byType(LoadingView), findsOneWidget);
    });
  });
}
