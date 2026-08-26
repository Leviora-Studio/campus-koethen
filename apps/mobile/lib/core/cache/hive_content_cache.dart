// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'dart:convert';

import 'package:flutter/foundation.dart' show compute, visibleForTesting;
import 'package:hive_ce_flutter/hive_flutter.dart';

import '../network/json.dart';
import 'cache_keys.dart';
import 'content_cache.dart';

/// `hive_ce` backed [ContentCache].
///
/// Documents are stored as JSON strings. That keeps the box free of custom
/// type adapters (no build_runner, no generated files) and makes a corrupted
/// entry a local, recoverable problem: it is dropped on read.
class HiveContentCache implements ContentCache {
  HiveContentCache(this._box);

  static const String boxName = 'campus_content_cache_v1';
  static const String _payloadKey = 'payload';
  static const String _cachedAtKey = 'cachedAt';

  final Box<String> _box;

  /// Opens the cache box. Returns a [MemoryContentCache] when Hive is not
  /// usable on this device, so the app keeps working without persistence.
  static Future<ContentCache> open() async {
    try {
      await Hive.initFlutter();
      final Box<String> box = await Hive.openBox<String>(boxName);
      await _deleteLegacyNewsKeys(box);
      return SafeContentCache(HiveContentCache(box));
    } catch (_) {
      return SafeContentCache(MemoryContentCache());
    }
  }

  /// One-time, idempotent cleanup of every `news.*` entry left over from the
  /// News → Posts rename. Only entries with that prefix are touched — every
  /// other module's cache entries in this shared box are left alone. Safe to
  /// run on every open: after the first successful run there is nothing left
  /// to delete.
  static Future<void> _deleteLegacyNewsKeys(Box<String> box) async {
    final List<String> legacyKeys = box.keys
        .whereType<String>()
        .where(CacheKeys.isLegacyNewsKey)
        .toList(growable: false);
    if (legacyKeys.isNotEmpty) await box.deleteAll(legacyKeys);
  }

  @override
  Future<CacheEntry?> read(String key) async {
    final String? raw = _box.get(key);
    if (raw == null) return null;
    final Map<String, dynamic>? envelope = asJsonMap(
      await decodeCacheDocument(raw),
    );
    if (envelope == null) return null;
    final Map<String, dynamic>? payload = asJsonMap(envelope[_payloadKey]);
    final DateTime? cachedAt = asDateTime(envelope[_cachedAtKey]);
    if (payload == null || cachedAt == null) return null;
    return CacheEntry(payload: payload, cachedAt: cachedAt);
  }

  @override
  Future<void> write(String key, Map<String, dynamic> payload) async {
    final String raw = jsonEncode(<String, dynamic>{
      _cachedAtKey: DateTime.now().toUtc().toIso8601String(),
      _payloadKey: payload,
    });
    await _box.put(key, raw);
  }

  @override
  Future<void> delete(String key) async {
    await _box.delete(key);
  }
}

/// Above this many characters a cached document is decoded in its own isolate.
///
/// The network path already works this way: dio's default transformer moves
/// any JSON response past 50 KB off the UI isolate, because below that the
/// decode is a couple of milliseconds and above it the frame is gone. The
/// cache carries exactly the same documents — the news page with every
/// article's content blocks, a calendar month, a canteen plan — but decoded
/// them on the UI isolate, on the one path where it matters most: the cold
/// start and the offline read, immediately before the first frame.
///
/// Writing keeps the direct path. Handing the payload to an isolate would copy
/// the whole map there and the encoded string back, which costs about as much
/// as the encode itself, and there is no cheap way to know the size before
/// encoding.
@visibleForTesting
const int kCacheDecodeIsolateThreshold = 50 * 1024;

/// Decodes one cached document, off the UI isolate when it is large enough to
/// be worth it.
///
/// A malformed entry yields `null` rather than throwing — the same contract
/// [ContentCache] states: a cache is an optimisation and degrades to a plain
/// network fetch, it never takes down a screen.
@visibleForTesting
Future<Object?> decodeCacheDocument(String raw) async {
  try {
    if (raw.length < kCacheDecodeIsolateThreshold) return jsonDecode(raw);
    return await compute(jsonDecode, raw);
  } catch (_) {
    return null;
  }
}
