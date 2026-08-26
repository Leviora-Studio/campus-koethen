// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'dart:ui' show Locale;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../prefs/settings_controller.dart';
import 'locale_mode.dart';

/// The locale explicitly selected by the user.
final Provider<Locale> activeLocaleProvider = Provider<Locale>((Ref ref) {
  final LocaleMode mode = ref.watch(
    settingsProvider.select((AppSettings settings) => settings.localeMode),
  );
  return mode.locale;
});

/// `de` or `en` — the value sent to the API and used for intl formatting.
final Provider<String> localeCodeProvider = Provider<String>(
  (Ref ref) => ref.watch(activeLocaleProvider).languageCode,
);

/// The translations, outside the widget tree.
///
/// Everything the user reads is normally reached through `context.l10n`, and
/// that stays the rule. This provider exists for the one case that has no
/// context and cannot get one: a notification is written **before** it is
/// shown, by a provider, and its text is frozen into the operating system's
/// store at that moment. Watching it here means a language change rebuilds
/// every candidate and therefore re-schedules every pending notification in
/// the new language — the same path any other data change takes.
final Provider<AppLocalizations> appLocalizationsProvider =
    Provider<AppLocalizations>(
      (Ref ref) => lookupAppLocalizations(ref.watch(activeLocaleProvider)),
    );
