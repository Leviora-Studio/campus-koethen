// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'grade_credentials.dart';

/// Stores the QIS credentials in the device keychain/keystore. There is no
/// insecure fallback: if the secure backend is unavailable, [write] throws.
abstract interface class GradeCredentialStore {
  Future<GradeCredentials?> read();
  Future<void> write(GradeCredentials credentials);
  Future<void> clear();
}
