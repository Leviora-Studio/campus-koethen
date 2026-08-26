// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:campus_koethen/core/cache/cache_providers.dart';
import 'package:campus_koethen/core/cache/content_cache.dart';
import 'package:campus_koethen/core/locale/locale_mode.dart';
import 'package:campus_koethen/core/prefs/key_value_store.dart';
import 'package:campus_koethen/core/prefs/settings_controller.dart';
import 'package:campus_koethen/core/theme/app_theme.dart';
import 'package:campus_koethen/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

/// Pumps a single screen with the full localisation and theme setup.
///
/// Defaults to an in-memory key/value store and an in-memory cache, so no test
/// ever touches the file system.
///
/// The store and cache are dedicated PARAMETERS rather than entries in
/// [overrides]: Riverpod asserts when the same provider is overridden twice in
/// one container, so a caller supplying its own via [overrides] would collide
/// with the defaults below. Passing them here makes that impossible.
Future<ProviderContainer> pumpScreen(
  WidgetTester tester,
  Widget child, {
  List<Override> overrides = const <Override>[],
  KeyValueStore? keyValueStore,
  ContentCache? contentCache,
  Locale locale = AppLocales.german,
  ThemeMode themeMode = ThemeMode.light,
  TextScaler textScaler = TextScaler.noScaling,
}) async {
  final ProviderContainer container = ProviderContainer(
    overrides: <Override>[
      keyValueStoreProvider.overrideWithValue(
        keyValueStore ?? InMemoryKeyValueStore(),
      ),
      contentCacheProvider.overrideWithValue(
        contentCache ?? SafeContentCache(MemoryContentCache()),
      ),
      ...overrides,
    ],
  );
  addTearDown(container.dispose);

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: themeMode,
        locale: locale,
        supportedLocales: AppLocales.supported,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        builder: (BuildContext context, Widget? widget) => MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: textScaler),
          child: widget ?? const SizedBox.shrink(),
        ),
        home: child,
      ),
    ),
  );
  return container;
}
