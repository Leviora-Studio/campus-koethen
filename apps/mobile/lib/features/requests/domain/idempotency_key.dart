// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'dart:math';

/// The key that makes a retry safe.
///
/// The endpoint requires one per submission and defines the contract precisely:
/// the **same** key with the **same** data replays the original answer and files
/// nothing twice; the same key with **different** data is a conflict; a new
/// application needs a new key. So the key belongs to the *draft* and is
/// generated once, when the draft is created — not at the moment of sending,
/// which would defeat the entire purpose the first time a submission times out.
///
/// Generated with [Random.secure]: a predictable key is a key somebody else can
/// collide with.
abstract final class IdempotencyKey {
  static final Random _random = Random.secure();

  /// A UUID v4, the format the API recommends.
  static String generate() {
    final List<int> bytes = List<int>.generate(
      16,
      (_) => _random.nextInt(256),
      growable: false,
    );
    // Version 4, variant 1 — the two fixed nibbles of a random UUID.
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    final String hex = bytes
        .map((int b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-'
        '${hex.substring(20)}';
  }

  /// What the endpoint accepts: printable ASCII, 16 to 128 characters.
  ///
  /// Checked before sending because a stored draft is untrusted input too — a
  /// key restored from an older version, or hand-edited, must not turn into a
  /// 400 that reads like a server fault.
  static bool isValid(String? value) {
    if (value == null) return false;
    if (value.length < 16 || value.length > 128) return false;
    return value.codeUnits.every((int c) => c >= 0x20 && c <= 0x7e);
  }
}
