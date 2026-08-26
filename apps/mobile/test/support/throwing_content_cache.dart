// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:campus_koethen/core/cache/content_cache.dart';

/// A cache that fails on every single operation.
///
/// Used to prove that a broken persistence layer degrades the app to plain
/// network access instead of crashing a screen.
class ThrowingContentCache implements ContentCache {
  int readAttempts = 0;
  int writeAttempts = 0;

  @override
  Future<CacheEntry?> read(String key) async {
    readAttempts++;
    throw StateError('cache box is corrupted');
  }

  @override
  Future<void> write(String key, Map<String, dynamic> payload) async {
    writeAttempts++;
    throw StateError('cache box is read-only');
  }

  @override
  Future<void> delete(String key) async {
    throw StateError('cache box is read-only');
  }
}
