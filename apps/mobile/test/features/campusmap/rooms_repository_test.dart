// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:campus_koethen/core/cache/cache_keys.dart';
import 'package:campus_koethen/core/cache/content_cache.dart';
import 'package:campus_koethen/core/network/loaded.dart';
import 'package:campus_koethen/features/campusmap/data/rooms_repository.dart';
import 'package:campus_koethen/features/campusmap/domain/room.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_http_adapter.dart';

Map<String, dynamic> _room(String key) => <String, dynamic>{
  'roomKey': key,
  'roomNumber': 'B.201',
  'buildingKey': 'test-building',
  'buildingName': 'Testgebäude',
  'floorKey': 'test-building-level2',
  'floorName': '2. Obergeschoss',
  'roomType': 'office',
  'mapVersion': 'demo-1',
  'sortOrder': 10,
};

Map<String, dynamic> _cachedEnvelope(String roomKey) => <String, dynamic>{
  'data': <Map<String, dynamic>>[_room(roomKey)],
  'meta': <String, dynamic>{
    'requestedLocale': 'de',
    'resolvedLocale': 'de',
    'translationFallback': false,
  },
};

class _SeededCache implements ContentCache {
  _SeededCache(this.entry);

  CacheEntry? entry;

  @override
  Future<CacheEntry?> read(String key) async => entry;

  @override
  Future<void> write(String key, Map<String, dynamic> payload) async {
    entry = CacheEntry(payload: payload, cachedAt: DateTime.now());
  }

  @override
  Future<void> delete(String key) async => entry = null;
}

RoomsRepository _repository(FakeHttpAdapter adapter, ContentCache cache) =>
    RoomsRepository(client: fakeApiClient(adapter), cache: cache);

void main() {
  test('reuses a room catalogue younger than twelve hours', () async {
    final _SeededCache cache = _SeededCache(
      CacheEntry(
        payload: _cachedEnvelope('cached-room'),
        cachedAt: DateTime.now().subtract(const Duration(hours: 11)),
      ),
    );
    final FakeHttpAdapter adapter = FakeHttpAdapter(
      (RequestOptions _) => throw StateError('network must not be called'),
    );

    final Loaded<List<Room>> loaded = await _repository(
      adapter,
      cache,
    ).fetchRooms(locale: 'de');

    expect(loaded.value.single.roomKey, 'cached-room');
    expect(loaded.fromCache, isFalse);
    expect(adapter.requests, isEmpty);
  });

  test('refreshes a room catalogue older than twelve hours', () async {
    final _SeededCache cache = _SeededCache(
      CacheEntry(
        payload: _cachedEnvelope('old-room'),
        cachedAt: DateTime.now().subtract(const Duration(hours: 13)),
      ),
    );
    final FakeHttpAdapter adapter = FakeHttpAdapter(
      (RequestOptions _) => FakeHttpResponse(
        envelope(<Map<String, dynamic>>[_room('fresh-room')]),
      ),
    );

    final Loaded<List<Room>> loaded = await _repository(
      adapter,
      cache,
    ).fetchRooms(locale: 'de');

    expect(loaded.value.single.roomKey, 'fresh-room');
    expect(loaded.fromCache, isFalse);
    expect(adapter.requests.single.path, '/rooms');
  });

  test('keeps an expired room catalogue when refresh fails offline', () async {
    final DateTime cachedAt = DateTime.now().subtract(
      const Duration(hours: 13),
    );
    final _SeededCache cache = _SeededCache(
      CacheEntry(payload: _cachedEnvelope('offline-room'), cachedAt: cachedAt),
    );
    final FakeHttpAdapter adapter = FakeHttpAdapter(
      (RequestOptions _) => throw StateError('offline'),
    );

    final Loaded<List<Room>> loaded = await _repository(
      adapter,
      cache,
    ).fetchRooms(locale: 'de');

    expect(loaded.value.single.roomKey, 'offline-room');
    expect(loaded.fromCache, isTrue);
    expect(loaded.cachedAt, cachedAt);
    expect(adapter.requests, hasLength(1));
  });

  test('room cache remains separated by locale', () {
    expect(CacheKeys.rooms('de'), isNot(CacheKeys.rooms('en')));
  });
}
