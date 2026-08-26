// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/security/app_secure_storage.dart';
import '../domain/grade_credential_store.dart';
import '../domain/grade_credentials.dart';
import '../domain/grade_failure.dart';

/// [GradeCredentialStore] backed by the device keychain/keystore.
///
/// There is NO SharedPreferences, plain Hive or plaintext fallback: if the
/// secure backend is unavailable, [write] throws so the caller refuses to store
/// the account rather than downgrading to insecure storage. The password is
/// never logged and lives nowhere but here.
class SecureGradeCredentialStore implements GradeCredentialStore {
  SecureGradeCredentialStore([FlutterSecureStorage? storage])
    : _storage = storage ?? appSecureStorage();

  final FlutterSecureStorage _storage;

  static const String _userKey = 'grades.qis.username';
  static const String _passwordKey = 'grades.qis.password';

  @override
  Future<GradeCredentials?> read() async {
    try {
      final String? username = await _storage.read(key: _userKey);
      final String? password = await _storage.read(key: _passwordKey);
      if (username == null || password == null) return null;
      return GradeCredentials(username: username, password: password);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(GradeCredentials credentials) async {
    try {
      await _storage.write(key: _userKey, value: credentials.username);
      await _storage.write(key: _passwordKey, value: credentials.password);
    } catch (_) {
      try {
        await clear();
      } catch (_) {}
      throw const GradeFailure(GradeFailureKind.secureStorageUnavailable);
    }
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _userKey);
    await _storage.delete(key: _passwordKey);
  }
}
