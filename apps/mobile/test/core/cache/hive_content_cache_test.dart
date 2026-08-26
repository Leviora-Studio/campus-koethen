// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'dart:convert';
import 'dart:io';

import 'package:campus_koethen/core/cache/content_cache.dart';
import 'package:campus_koethen/core/cache/hive_content_cache.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

/// A payload comfortably past [kCacheDecodeIsolateThreshold], so the read
/// takes the background path.
Map<String, dynamic> _largePayload() => <String, dynamic>{
  'articles': <Map<String, dynamic>>[
    for (int i = 0; i < 400; i++)
      <String, dynamic>{
        'slug': 'artikel-$i',
        'title': 'Überschrift $i',
        'body':
            'Ein Absatz mit genug Text, um das Dokument wachsen zu lassen. '
                'Wiederholt, damit die Schwelle real überschritten wird. ' *
            2,
      },
  ],
};

void main() {
  late Directory directory;
  late Box<String> box;
  late HiveContentCache cache;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('content-cache-test-');
    Hive.init(directory.path);
    box = await Hive.openBox<String>('content-cache-test');
    cache = HiveContentCache(box);
  });

  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
  });

  test('a small document round-trips on the direct path', () async {
    await cache.write('small', <String, dynamic>{
      'data': <String>['a', 'b'],
    });

    final CacheEntry? entry = await cache.read('small');

    expect(entry, isNotNull);
    expect(entry!.payload['data'], <String>['a', 'b']);
    expect(box.get('small')!.length, lessThan(kCacheDecodeIsolateThreshold));
  });

  test('a large document round-trips through the background isolate', () async {
    final Map<String, dynamic> payload = _largePayload();
    await cache.write('large', payload);

    expect(
      box.get('large')!.length,
      greaterThan(kCacheDecodeIsolateThreshold),
      reason: 'the fixture has to cross the threshold to test that path',
    );

    final CacheEntry? entry = await cache.read('large');

    expect(entry, isNotNull);
    expect(
      (entry!.payload['articles'] as List<dynamic>).length,
      (payload['articles'] as List<dynamic>).length,
    );
    expect(
      (entry.payload['articles'] as List<dynamic>).last,
      (payload['articles'] as List<dynamic>).last,
    );
  });

  test('a missing key reads as null', () async {
    expect(await cache.read('nothing'), isNull);
  });

  test('a corrupt entry is dropped rather than thrown', () async {
    await box.put('broken', '{not json');
    expect(await cache.read('broken'), isNull);
  });

  test('an envelope without a payload or a timestamp is dropped', () async {
    await box.put('bare', jsonEncode(<String, dynamic>{'payload': null}));
    expect(await cache.read('bare'), isNull);
  });

  group('decodeCacheDocument', () {
    test('decodes below and above the threshold alike', () async {
      final String small = jsonEncode(<String, dynamic>{'a': 1});
      final String large = jsonEncode(_largePayload());
      expect(large.length, greaterThan(kCacheDecodeIsolateThreshold));

      expect(await decodeCacheDocument(small), <String, dynamic>{'a': 1});
      expect(
        ((await decodeCacheDocument(large))!
            as Map<String, dynamic>)['articles'],
        hasLength(400),
      );
    });

    test('malformed input yields null on both paths', () async {
      expect(await decodeCacheDocument('{nope'), isNull);
      expect(await decodeCacheDocument('{${'"x":1,' * 20000}'), isNull);
    });
  });
}
