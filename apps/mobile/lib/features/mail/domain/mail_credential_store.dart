// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'mail_credentials.dart';

/// Persistence boundary for the mail login.
///
/// The production implementation is backed by the device keychain/keystore via
/// flutter_secure_storage. There is deliberately NO SharedPreferences or Hive
/// fallback: if secure storage is unavailable the credentials are simply not
/// stored, and the caller surfaces a clear error. Tests use an in-memory fake
/// only — never the real platform channel.
abstract interface class MailCredentialStore {
  /// Returns the stored credentials, or null if none are set.
  Future<MailCredentials?> read();

  /// Persists the credentials. Throws [MailFailure] with
  /// [MailFailureKind.secureStorageUnavailable] if secure storage cannot be used.
  Future<void> write(MailCredentials credentials);

  /// Removes the email address AND the password completely.
  Future<void> clear();
}
