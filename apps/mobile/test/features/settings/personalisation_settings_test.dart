// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:campus_koethen/app/app_modules.dart';
import 'package:campus_koethen/core/locale/locale_mode.dart';
import 'package:campus_koethen/core/prefs/key_value_store.dart';
import 'package:campus_koethen/core/prefs/preference_keys.dart';
import 'package:campus_koethen/core/prefs/settings_controller.dart';
import 'package:campus_koethen/core/theme/app_motion.dart';
import 'package:campus_koethen/core/theme/app_theme.dart';
import 'package:campus_koethen/features/settings/presentation/navigation_settings_screen.dart';
import 'package:campus_koethen/features/settings/presentation/personalisation_tiles.dart';
import 'package:campus_koethen/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import "package:campus_koethen/core/theme/app_icons.dart";

/// Pumps a widget inside a MaterialApp whose theme is built from the live
/// settings — the only way to assert that a preference actually reaches the
/// rendered theme rather than just the store.
Future<ProviderContainer> pumpThemed(
  WidgetTester tester,
  Widget child, {
  KeyValueStore? store,
  Locale locale = AppLocales.german,
  Size surface = const Size(390, 1800),
}) async {
  tester.view.physicalSize = surface;
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  final ProviderContainer container = ProviderContainer(
    overrides: <Override>[
      keyValueStoreProvider.overrideWithValue(store ?? InMemoryKeyValueStore()),
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: Consumer(
        builder: (BuildContext context, WidgetRef ref, Widget? _) {
          final AppSettings settings = ref.watch(settingsProvider);
          return MaterialApp(
            locale: locale,
            supportedLocales: AppLocales.supported,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            theme: AppTheme.light(
              motion: AppMotion.resolve(
                systemDisablesAnimations: false,
                userPrefersReducedMotion: settings.reducedMotion,
              ),
            ),
            home: child,
          );
        },
      ),
    ),
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  group('reduced motion', () {
    testWidgets('the switch reaches the theme', (WidgetTester tester) async {
      final ProviderContainer container = await pumpThemed(
        tester,
        const Scaffold(body: ReducedMotionTile()),
      );

      AppMotion motion() => Theme.of(
        tester.element(find.byType(ReducedMotionTile)),
      ).extension<AppMotion>()!;
      expect(motion().reduced, isFalse);

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(motion().reduced, isTrue);
      expect(motion().medium, Duration.zero);
      expect(container.read(settingsProvider).reducedMotion, isTrue);
    });
  });

  group('navigation settings', () {
    testWidgets('More is shown as fixed and cannot be changed', (
      WidgetTester tester,
    ) async {
      await pumpThemed(tester, const NavigationSettingsScreen());

      expect(find.byIcon(AppIcons.lock_outline), findsOneWidget);
      expect(find.text('Mehr'), findsOneWidget);
    });

    testWidgets('the four active tabs are listed with a drag handle', (
      WidgetTester tester,
    ) async {
      await pumpThemed(tester, const NavigationSettingsScreen());

      for (final String title in <String>[
        'News',
        'Kalender',
        'Mensa',
        'Studentische E-Mail',
      ]) {
        expect(find.text(title), findsOneWidget, reason: title);
      }
      expect(find.byIcon(AppIcons.drag_handle), findsNWidgets(4));
    });

    testWidgets('a full bar offers no further module', (
      WidgetTester tester,
    ) async {
      // Adding a fifth must be unavailable rather than silently evicting
      // somebody else's pick.
      await pumpThemed(tester, const NavigationSettingsScreen());

      final Iterable<IconButton> adders = tester.widgetList<IconButton>(
        find.widgetWithIcon(IconButton, AppIcons.add_circle_outline),
      );
      expect(adders, isNotEmpty);
      for (final IconButton button in adders) {
        expect(button.onPressed, isNull);
      }
    });

    testWidgets('removing one and adding another is persisted', (
      WidgetTester tester,
    ) async {
      final InMemoryKeyValueStore store = InMemoryKeyValueStore();
      await pumpThemed(
        tester,
        const NavigationSettingsScreen(),
        store: store,
        // Tall enough that both lists are laid out at once: the editor is a
        // single ListView, and an add button below the fold is not tappable.
        surface: const Size(390, 3000),
      );

      await tester.tap(
        find.widgetWithIcon(IconButton, AppIcons.remove_circle_outline).first,
      );
      await tester.pumpAndSettle();

      // A larger surface instead of scrolling: scrollUntilVisible needs a
      // finder that matches exactly one widget, and every free slot offers an
      // add button.
      await tester.tap(
        find.widgetWithIcon(IconButton, AppIcons.add_circle_outline).first,
        warnIfMissed: false,
      );
      await tester.pumpAndSettle();

      final List<String>? stored = store.getStringList(
        PreferenceKeys.navigationTabs,
      );
      expect(stored, hasLength(4));
      expect(stored, isNot(contains(AppModule.news.storageValue)));
      expect(stored!.toSet(), hasLength(4));
    });
  });
}
