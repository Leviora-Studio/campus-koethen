// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/security/app_secure_storage.dart';
import '../domain/mail_credential_store.dart';
import '../domain/mail_credentials.dart';
import '../domain/mail_failure.dart';

/// [MailCredentialStore] backed by the device keychain/keystore.
///
/// There is NO SharedPreferences or Hive fallback by design: if the secure
/// backend is unavailable, [write] throws so the caller can refuse to store the
/// account rather than silently downgrading to insecure storage. The password
/// is never logged and never placed anywhere but here.
class SecureMailCredentialStore implements MailCredentialStore {
  SecureMailCredentialStore([FlutterSecureStorage? storage])
    : _storage = storage ?? appSecureStorage();

  final FlutterSecureStorage _storage;

  static const String emailKey = 'mail.hsa.email';
  static const String passwordKey = 'mail.hsa.password';
  static const String nameKey = 'mail.hsa.name';

  @override
  Future<MailCredentials?> read() async {
    try {
      final String? email = await _storage.read(key: emailKey);
      final String? password = await _storage.read(key: passwordKey);
      if (email == null || password == null) return null;
      final String? name = await _storage.read(key: nameKey);
      return MailCredentials(
        emailAddress: email,
        password: password,
        displayName: (name != null && name.isNotEmpty) ? name : null,
      );
    } catch (_) {
      throw const MailFailure(MailFailureKind.secureStorageUnavailable);
    }
  }

  @override
  Future<void> write(MailCredentials credentials) async {
    try {
      await _storage.write(key: emailKey, value: credentials.emailAddress);
      await _storage.write(key: passwordKey, value: credentials.password);
      final String? name = credentials.displayName;
      if (name != null && name.isNotEmpty) {
        await _storage.write(key: nameKey, value: name);
      } else {
        await _storage.delete(key: nameKey);
      }
    } catch (_) {
      // Do not leak the platform exception (it could echo written values);
      // surface only the classification. Best-effort clean up a partial write.
      try {
        await clear();
      } catch (_) {}
      throw const MailFailure(MailFailureKind.secureStorageUnavailable);
    }
  }

  @override
  Future<void> clear() async {
    bool complete = true;
    for (final String key in <String>[emailKey, passwordKey, nameKey]) {
      try {
        await _storage.delete(key: key);
        if (await _storage.read(key: key) != null) complete = false;
      } catch (_) {
        complete = false;
      }
    }
    if (!complete) {
      throw const MailFailure(MailFailureKind.localDataWipeIncomplete);
    }
  }
}
