// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/security/app_secure_storage.dart';
import '../domain/grade_portal.dart';
import '../domain/grade_portal_store.dart';

/// [GradePortalStore] backed by the device keychain/keystore — the same
/// secure-storage mechanism as [SecureGradeCredentialStore], so deleting the
/// account removes the portal choice in the same step.
class SecureGradePortalStore implements GradePortalStore {
  SecureGradePortalStore([FlutterSecureStorage? storage])
    : _storage = storage ?? appSecureStorage();

  final FlutterSecureStorage _storage;

  static const String _portalKey = 'grades.active.portal';

  @override
  Future<GradePortal?> read() async {
    try {
      final String? raw = await _storage.read(key: _portalKey);
      for (final GradePortal p in GradePortal.values) {
        if (p.name == raw) return p;
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> write(GradePortal portal) async {
    try {
      await _storage.write(key: _portalKey, value: portal.name);
    } catch (_) {}
  }

  @override
  Future<void> clear() async {
    try {
      await _storage.delete(key: _portalKey);
    } catch (_) {}
  }
}
