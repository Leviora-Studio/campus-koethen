// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:campus_koethen/app/app_router.dart';
import 'package:campus_koethen/app/takt_navigation_bar.dart';
import 'package:campus_koethen/core/cache/cache_providers.dart';
import 'package:campus_koethen/core/cache/content_cache.dart';
import 'package:campus_koethen/core/locale/locale_mode.dart';
import 'package:campus_koethen/core/network/network_providers.dart';
import 'package:campus_koethen/core/prefs/key_value_store.dart';
import 'package:campus_koethen/core/prefs/settings_controller.dart';
import 'package:campus_koethen/core/theme/app_icons.dart';
import 'package:campus_koethen/core/theme/app_motion.dart';
import 'package:campus_koethen/core/theme/app_theme.dart';
import 'package:campus_koethen/features/more/presentation/more_screen.dart';
import 'package:campus_koethen/features/news/presentation/news_list_screen.dart';
import 'package:campus_koethen/features/settings/presentation/settings_screen.dart';
import 'package:campus_koethen/l10n/l10n.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_http_adapter.dart';

/// Pumps the full app including the router and the bottom navigation.
Future<ProviderContainer> pumpApp(
  WidgetTester tester, {
  Locale locale = AppLocales.german,
  KeyValueStore? store,
  bool userTestData = false,
  AppMotion motion = AppMotion.enabled,
  TargetPlatform? platform,
}) async {
  final ProviderContainer container = ProviderContainer(
    overrides: <Override>[
      keyValueStoreProvider.overrideWithValue(store ?? InMemoryKeyValueStore()),
      contentCacheProvider.overrideWithValue(
        SafeContentCache(MemoryContentCache()),
      ),
      // An empty envelope rather than a thrown request: these tests assert the
      // navigation bar, not offline behaviour, and a throwing adapter leaves a
      // retry timer pending once the dashboard is the first screen.
      apiClientProvider.overrideWithValue(
        fakeApiClient(
          FakeHttpAdapter(
            (RequestOptions options) => FakeHttpResponse(
              envelope(
                options.path.endsWith('/environment')
                    ? <String, Object?>{'userTestData': userTestData}
                    : <Object>[],
              ),
            ),
          ),
        ),
      ),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        // The transition — and with it the iOS back swipe — is chosen from
        // `ThemeData.platform`, so a test names the platform here rather than
        // reaching for the global override.
        theme: platform == null
            ? AppTheme.light(motion: motion)
            : AppTheme.light(motion: motion).copyWith(platform: platform),
        locale: locale,
        supportedLocales: AppLocales.supported,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        routerConfig: createAppRouter(),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('offers five destinations in the agreed order', (
    WidgetTester tester,
  ) async {
    await pumpApp(tester);

    final TaktNavigationBar bar = tester.widget<TaktNavigationBar>(
      find.byType(TaktNavigationBar),
    );

    expect(
      bar.destinations.cast<TaktDestination>().map(
        (TaktDestination destination) => destination.label,
      ),
      // Four modules the user may change, then a fixed More. The four here are
      // the product defaults until the user picks otherwise.
      <String>['News', 'Kalender', 'Mensa', 'E-Mail', 'Mehr'],
    );
    expect(bar.destinations.last.icon, AppIcons.grid_on_outlined);
    expect(bar.destinations.last.selectedIcon, AppIcons.grid_on_outlined);
  });

  testWidgets('navigates to the calendar', (WidgetTester tester) async {
    await pumpApp(tester);

    await tester.tap(
      find.descendant(
        of: find.byType(TaktNavigationBar),
        matching: find.text('Kalender'),
      ),
    );
    await tester.pumpAndSettle();

    // The calendar's explicit view toggle (month vs list) is shown.
    expect(find.text('Liste'), findsOneWidget);
  });

  testWidgets('starts on the news feed', (WidgetTester tester) async {
    await pumpApp(tester);

    expect(find.byType(NewsListScreen), findsOneWidget);
    // The calendar view toggle is not shown until the Kalender tab is opened.
    expect(find.text('Liste'), findsNothing);
  });

  testWidgets('keeps five destinations usable on a narrow device', (
    WidgetTester tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(320, 640);
    addTearDown(tester.view.reset);

    await pumpApp(tester);

    expect(tester.takeException(), isNull);
    for (final String label in <String>[
      'News',
      'Kalender',
      'Mensa',
      'E-Mail',
      'Mehr',
    ]) {
      expect(
        find.descendant(
          of: find.byType(TaktNavigationBar),
          matching: find.text(label),
        ),
        findsOneWidget,
        reason: '$label is missing from the navigation bar',
      );
    }

    final Size barSize = tester.getSize(find.byType(TaktNavigationBar));
    expect(
      barSize.height,
      greaterThanOrEqualTo(48.0),
      reason: 'the navigation bar keeps a 48dp touch target',
    );
    expect(
      barSize.width / 5,
      greaterThanOrEqualTo(48.0),
      reason: 'every one of the five destinations stays hittable',
    );

    await tester.tap(
      find.descendant(
        of: find.byType(TaktNavigationBar),
        matching: find.text('Kalender'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Liste'), findsOneWidget);
  });

  testWidgets('renders the English navigation', (WidgetTester tester) async {
    await pumpApp(tester, locale: AppLocales.english);

    await tester.tap(find.text('Calendar'));
    await tester.pumpAndSettle();

    expect(find.text('List'), findsOneWidget);
  });

  group('iOS back swipe', () {
    /// Opens the settings page, which is pushed onto the "Mehr" branch and is
    /// therefore a sub-page with something to go back to.
    Future<void> openSettings(WidgetTester tester) async {
      await tester.tap(
        find.descendant(
          of: find.byType(TaktNavigationBar),
          matching: find.text('Mehr'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(AppIcons.settings_outlined));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);
    }

    /// A drag from the left edge, slow enough not to count as a fling, so the
    /// distance alone decides whether the page goes back.
    Future<void> swipeFromLeftEdge(WidgetTester tester, double distance) async {
      final TestGesture gesture = await tester.startGesture(
        const Offset(2, 300),
      );
      for (int step = 0; step < 10; step++) {
        await gesture.moveBy(Offset(distance / 10, 0));
        await tester.pump(const Duration(milliseconds: 20));
      }
      await gesture.up();
      await tester.pumpAndSettle();
    }

    testWidgets('takes a pushed sub-page back', (WidgetTester tester) async {
      await pumpApp(tester, platform: TargetPlatform.iOS);
      await openSettings(tester);

      await swipeFromLeftEdge(tester, 600);

      expect(find.byType(SettingsScreen), findsNothing);
      expect(find.byType(MoreScreen), findsOneWidget);
    });

    testWidgets('leaves the page open when the swipe is withdrawn', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester, platform: TargetPlatform.iOS);
      await openSettings(tester);

      // Short of half the width and without the velocity of a fling: the
      // gesture is cancelled and the page settles back where it was.
      await swipeFromLeftEdge(tester, 60);

      expect(find.byType(SettingsScreen), findsOneWidget);
      expect(tester.takeException(), isNull);

      // And the back arrow still gets out of the same page.
      await tester.tap(find.byIcon(AppIcons.arrow_back).first);
      await tester.pumpAndSettle();
      expect(find.byType(MoreScreen), findsOneWidget);
    });

    testWidgets('the back arrow keeps working after the change', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester, platform: TargetPlatform.iOS);
      await openSettings(tester);

      await tester.tap(find.byIcon(AppIcons.arrow_back).first);
      await tester.pumpAndSettle();

      expect(find.byType(SettingsScreen), findsNothing);
      expect(find.byType(MoreScreen), findsOneWidget);
    });

    testWidgets('does nothing on a branch root', (WidgetTester tester) async {
      await pumpApp(tester, platform: TargetPlatform.iOS);
      await tester.tap(
        find.descendant(
          of: find.byType(TaktNavigationBar),
          matching: find.text('Mehr'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(MoreScreen), findsOneWidget);

      await swipeFromLeftEdge(tester, 600);

      // The tab is still there — the swipe neither closed it nor fell through
      // to the tab underneath.
      expect(find.byType(MoreScreen), findsOneWidget);
      expect(find.byType(TaktNavigationBar), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('keeps each branch stack when tabs are switched', (
      WidgetTester tester,
    ) async {
      await pumpApp(tester, platform: TargetPlatform.iOS);
      await openSettings(tester);

      await tester.tap(
        find.descendant(
          of: find.byType(TaktNavigationBar),
          matching: find.text('News'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(NewsListScreen), findsOneWidget);

      await tester.tap(
        find.descendant(
          of: find.byType(TaktNavigationBar),
          matching: find.text('Mehr'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SettingsScreen), findsOneWidget);
    });

    testWidgets('still works with reduced motion', (WidgetTester tester) async {
      await pumpApp(
        tester,
        motion: AppMotion.suppressed,
        platform: TargetPlatform.iOS,
      );
      await openSettings(tester);

      await swipeFromLeftEdge(tester, 600);

      expect(find.byType(SettingsScreen), findsNothing);
      expect(find.byType(MoreScreen), findsOneWidget);
    });
  });

  testWidgets('Android has no edge swipe back', (WidgetTester tester) async {
    await pumpApp(tester, platform: TargetPlatform.android);
    await tester.tap(
      find.descendant(
        of: find.byType(TaktNavigationBar),
        matching: find.text('Mehr'),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(AppIcons.settings_outlined));
    await tester.pumpAndSettle();

    final TestGesture gesture = await tester.startGesture(const Offset(2, 300));
    for (int step = 0; step < 10; step++) {
      await gesture.moveBy(const Offset(60, 0));
      await tester.pump(const Duration(milliseconds: 20));
    }
    await gesture.up();
    await tester.pumpAndSettle();

    // Unchanged: Android goes back through the system, not through a drag.
    expect(find.byType(SettingsScreen), findsOneWidget);

    // And the system back does go back.
    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();
    expect(find.byType(MoreScreen), findsOneWidget);
  });

  testWidgets(
    'discloses synthetic content once for the whole test environment',
    (WidgetTester tester) async {
      await pumpApp(tester, userTestData: true);

      expect(
        find.text('Testumgebung – Inhalte können synthetisch sein'),
        findsOneWidget,
      );
    },
  );
}
