// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/cache/encrypted_box.dart';
import '../domain/mail_cache_store.dart';
import '../domain/mail_credential_store.dart';
import '../domain/mail_credentials.dart';
import '../domain/mail_failure.dart';
import 'mail_cache.dart';

abstract interface class MailWipeIntentStore {
  Future<bool> isPending();
  Future<void> markPending();
  Future<void> clear();
}

class SecureMailWipeIntentStore implements MailWipeIntentStore {
  SecureMailWipeIntentStore([FlutterSecureStorage? storage])
    : _storage = storage ?? EncryptedBox.deviceSecureStorage();

  static const String key = 'mail.local_data_wipe_pending.v2';
  final FlutterSecureStorage _storage;

  @override
  Future<bool> isPending() async {
    try {
      return await _storage.read(key: key) == 'true';
    } catch (_) {
      throw const MailFailure(MailFailureKind.secureStorageUnavailable);
    }
  }

  @override
  Future<void> markPending() async {
    try {
      await _storage.write(key: key, value: 'true');
      if (await _storage.read(key: key) != 'true') throw StateError('marker');
    } catch (_) {
      throw const MailFailure(MailFailureKind.localDataWipeIncomplete);
    }
  }

  @override
  Future<void> clear() async {
    try {
      await _storage.delete(key: key);
      if (await _storage.read(key: key) != null) throw StateError('marker');
    } catch (_) {
      throw const MailFailure(MailFailureKind.localDataWipeIncomplete);
    }
  }
}

class MemoryMailWipeIntentStore implements MailWipeIntentStore {
  bool pending = false;

  @override
  Future<void> clear() async => pending = false;

  @override
  Future<bool> isPending() async => pending;

  @override
  Future<void> markPending() async => pending = true;
}

/// Orchestrates credentials, cache artifacts and the crash-recovery marker.
class MailLocalDataCoordinator {
  factory MailLocalDataCoordinator({
    required MailCredentialStore credentials,
    required MailCacheStore cache,
    required MailWipeIntentStore wipeIntent,
  }) => MailLocalDataCoordinator._(credentials, cache, wipeIntent);

  MailLocalDataCoordinator._(this._credentials, this._cache, this._wipeIntent);

  final MailCredentialStore _credentials;
  final MailCacheStore _cache;
  final MailWipeIntentStore _wipeIntent;

  bool _blockedByIncompleteWipe = false;

  Future<void> initialize() async {
    try {
      if (await _wipeIntent.isPending()) {
        _blockedByIncompleteWipe = true;
        await _continueWipe();
      }
      final MailCredentials? stored = await _credentials.read();
      if (_cache case final MailCacheManager manager) {
        final MailCacheInitResult result = await manager.initialize(
          accountExists: stored != null,
        );
        // No stored account plus an unconfirmed legacy/v2 cleanup means old
        // artifacts from a previous account may still be on disk. Block
        // credential reads and writes until a later initialize() confirms
        // they are gone — otherwise a fresh sign-in could reactivate them.
        if (stored == null && result.failure != null) {
          _blockedByIncompleteWipe = true;
        }
      }
    } catch (_) {
      _blockedByIncompleteWipe = true;
      if (_cache case final MailCacheManager manager) manager.lock();
    }
  }

  Future<MailCredentials?> readCredentials() async {
    _ensureAvailable();
    return _credentials.read();
  }

  Future<void> writeCredentials(MailCredentials credentials) async {
    _ensureAvailable();
    await _credentials.write(credentials);
    if (_cache case final MailCacheManager manager) {
      await manager.activate();
    }
  }

  Future<void> wipe({void Function()? onIntentRecorded}) async {
    await _wipeIntent.markPending();
    _blockedByIncompleteWipe = true;
    if (_cache case final MailCacheManager manager) manager.lock();
    onIntentRecorded?.call();
    await _continueWipe();
  }

  Future<void> _continueWipe() async {
    bool credentialsAbsent = false;
    bool cacheAbsent = false;
    try {
      await _credentials.clear();
      credentialsAbsent = await _credentials.read() == null;
    } catch (_) {}
    try {
      if (_cache case final MailCacheManager manager) {
        cacheAbsent = (await manager.wipe()).isComplete;
      } else {
        await _cache.clear();
        cacheAbsent = true;
      }
    } catch (_) {}

    if (!credentialsAbsent || !cacheAbsent) {
      throw const MailFailure(MailFailureKind.localDataWipeIncomplete);
    }
    await _wipeIntent.clear();
    _blockedByIncompleteWipe = false;
  }

  void _ensureAvailable() {
    if (_blockedByIncompleteWipe) {
      throw const MailFailure(MailFailureKind.localDataWipeIncomplete);
    }
  }
}
