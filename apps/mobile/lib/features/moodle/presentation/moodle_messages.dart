// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import '../../../l10n/l10n.dart';
import '../domain/moodle_failure.dart';

/// Maps a [MoodleFailure] to a localized, user-safe message.
///
/// Switches only on the typed kind — no token, password, URL, raw Moodle
/// response or course content ever reaches the UI.
String moodleFailureMessage(AppLocalizations l10n, Object? error) {
  if (error is MoodleFailure) {
    return switch (error.kind) {
      MoodleFailureKind.invalidCredentials =>
        l10n.moodleErrorInvalidCredentials,
      MoodleFailureKind.tokenRejected => l10n.moodleErrorTokenRejected,
      MoodleFailureKind.tokenExpired => l10n.moodleErrorTokenExpired,
      MoodleFailureKind.networkUnavailable => l10n.moodleErrorNetwork,
      MoodleFailureKind.timeout => l10n.moodleErrorTimeout,
      MoodleFailureKind.tlsOrHostRejected => l10n.moodleErrorTls,
      MoodleFailureKind.serviceUnavailable =>
        l10n.moodleErrorServiceUnavailable,
      MoodleFailureKind.permissionDenied => l10n.moodleErrorPermissionDenied,
      MoodleFailureKind.invalidResponse => l10n.moodleErrorInvalidResponse,
      MoodleFailureKind.unsupportedModule => l10n.moodleErrorUnsupportedModule,
      MoodleFailureKind.secureStorageUnavailable =>
        l10n.moodleErrorSecureStorage,
      MoodleFailureKind.cacheUnavailable => l10n.moodleErrorCache,
      MoodleFailureKind.fileTooLarge => l10n.moodleErrorFileTooLarge,
      MoodleFailureKind.downloadFailed => l10n.moodleErrorDownloadFailed,
      MoodleFailureKind.unknown => l10n.moodleErrorGeneric,
    };
  }
  return l10n.moodleErrorGeneric;
}

/// The course's display name, with a localised fallback.
///
/// Moodle occasionally returns a course without a usable name. The fallback
/// used to be a hardcoded German "Kurs 12" built down in the parser, which
/// showed up untranslated in the English UI — against the project's
/// no-hardcoded-UI-text rule. It belongs here, where a locale exists.
String moodleCourseName(AppLocalizations l10n, int id, String fullName) {
  final String name = fullName.trim();
  if (name.isNotEmpty) return name;
  return l10n.moodleCourseFallbackName('$id');
}
