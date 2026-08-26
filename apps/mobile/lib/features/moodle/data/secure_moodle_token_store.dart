// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/security/app_secure_storage.dart';
import '../domain/moodle_account.dart';
import '../domain/moodle_failure.dart';

/// [MoodleTokenStore] backed by the device keychain/keystore.
///
/// The token exists nowhere else: no SharedPreferences, no plain Hive, no
/// plaintext file, no Riverpod state, no static field and no log line. If the
/// secure backend is unavailable, [write] throws so the caller refuses to store
/// rather than downgrading to insecure storage.
class SecureMoodleTokenStore implements MoodleTokenStore {
  SecureMoodleTokenStore([FlutterSecureStorage? storage])
    : _storage = storage ?? appSecureStorage();

  final FlutterSecureStorage _storage;

  static const String _tokenKey = 'moodle.token';
  static const String _userIdKey = 'moodle.userid';
  static const String _usernameKey = 'moodle.username';
  static const String _siteNameKey = 'moodle.sitename';

  @override
  Future<MoodleToken?> read() async {
    try {
      final String? token = await _storage.read(key: _tokenKey);
      final String? userIdRaw = await _storage.read(key: _userIdKey);
      final int? userId = userIdRaw == null ? null : int.tryParse(userIdRaw);
      if (token == null || userId == null) return null;
      return MoodleToken(
        value: token,
        userId: userId,
        username: await _storage.read(key: _usernameKey),
        siteName: await _storage.read(key: _siteNameKey),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(MoodleToken token) async {
    try {
      await _storage.write(key: _tokenKey, value: token.value);
      await _storage.write(key: _userIdKey, value: '${token.userId}');
      if (token.username != null) {
        await _storage.write(key: _usernameKey, value: token.username);
      }
      if (token.siteName != null) {
        await _storage.write(key: _siteNameKey, value: token.siteName);
      }
    } catch (_) {
      try {
        await clear();
      } catch (_) {}
      throw const MoodleFailure(MoodleFailureKind.secureStorageUnavailable);
    }
  }

  @override
  Future<void> clear() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _userIdKey);
    await _storage.delete(key: _usernameKey);
    await _storage.delete(key: _siteNameKey);
  }
}
