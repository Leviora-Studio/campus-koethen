// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'dart:convert';

import 'package:hive_ce_flutter/hive_flutter.dart';

import '../domain/saved_event_snapshot.dart';

/// Persists the offline saved-events list ("Meine gemerkten Events").
///
/// Its own unencrypted `hive_ce` box, deliberately separate from the shared
/// content cache: this is user-authored data (what the reader chose to
/// remember), not a re-fetchable cache entry, and it is public campus data —
/// no account, no server sync, so it needs none of the encryption the mail or
/// grades caches require. All operations are best effort: a corrupt or
/// unavailable box degrades to "empty", never a crash — same contract as
/// `HiveTodoStore`.
abstract interface class SavedEventsStore {
  Future<List<SavedEventSnapshot>> readAll();
  Future<void> writeAll(List<SavedEventSnapshot> snapshots);
}

class HiveSavedEventsStore implements SavedEventsStore {
  static const String boxName = 'campus_saved_events_v1';
  static const String _itemsKey = 'items';

  Box<String>? _box;

  Future<Box<String>?> _open() async {
    if (_box != null && _box!.isOpen) return _box;
    try {
      await Hive.initFlutter();
      _box = await Hive.openBox<String>(boxName);
      return _box;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<SavedEventSnapshot>> readAll() async {
    final Box<String>? box = await _open();
    final String? raw = box?.get(_itemsKey);
    if (raw == null) return const <SavedEventSnapshot>[];
    try {
      return SavedEventSnapshot.listFromJson(jsonDecode(raw));
    } catch (_) {
      return const <SavedEventSnapshot>[];
    }
  }

  @override
  Future<void> writeAll(List<SavedEventSnapshot> snapshots) async {
    final Box<String>? box = await _open();
    if (box == null) return;
    try {
      await box.put(
        _itemsKey,
        jsonEncode(
          snapshots.map((SavedEventSnapshot s) => s.toJson()).toList(),
        ),
      );
    } catch (_) {
      // Losing a persistence write is acceptable; losing the screen is not.
    }
  }
}

/// In-memory store used by tests and as a safe fallback.
class MemorySavedEventsStore implements SavedEventsStore {
  List<SavedEventSnapshot> _items = const <SavedEventSnapshot>[];

  @override
  Future<List<SavedEventSnapshot>> readAll() async =>
      List<SavedEventSnapshot>.unmodifiable(_items);

  @override
  Future<void> writeAll(List<SavedEventSnapshot> snapshots) async {
    _items = List<SavedEventSnapshot>.unmodifiable(snapshots);
  }
}
