// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'dart:ui' show Locale;

/// Supported locales of the app. `de` is default **and** fallback.
abstract final class AppLocales {
  static const Locale german = Locale('de');
  static const Locale english = Locale('en');

  /// Default and fallback locale.
  static const Locale fallback = german;

  static const List<Locale> supported = <Locale>[german, english];
}

/// The user's explicit language preference.
enum LocaleMode {
  german('de'),
  english('en');

  const LocaleMode(this.storageValue);

  final String storageValue;

  Locale get locale => switch (this) {
    LocaleMode.german => AppLocales.german,
    LocaleMode.english => AppLocales.english,
  };

  static LocaleMode fromStorage(String? value) {
    for (final LocaleMode mode in LocaleMode.values) {
      if (mode.storageValue == value) return mode;
    }
    // Fresh installs, corrupt values and the removed legacy `system` value all
    // migrate deterministically to German.
    return LocaleMode.german;
  }
}
