// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:campus_koethen/core/prefs/key_value_store.dart';
import 'package:campus_koethen/core/prefs/settings_controller.dart';
import 'package:campus_koethen/features/news/application/tag_filter.dart';
import 'package:campus_koethen/features/news/data/news_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

NewsTag tag(String slug) => NewsTag(slug: slug, name: slug);

ProviderContainer containerWith(KeyValueStore store) {
  final ProviderContainer container = ProviderContainer(
    overrides: <Override>[keyValueStoreProvider.overrideWithValue(store)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('NewsTagFilterRules.reconcile', () {
    test('keeps "Alle" (null) as "Alle"', () {
      expect(
        NewsTagFilterRules.reconcile(
          available: <NewsTag>[tag('event')],
          selected: null,
        ),
        isNull,
      );
    });

    test('keeps a selection that is still offered', () {
      expect(
        NewsTagFilterRules.reconcile(
          available: <NewsTag>[tag('event'), tag('news')],
          selected: 'event',
        ),
        'event',
      );
    });

    test('falls back to "Alle" when the selected tag was removed', () {
      expect(
        NewsTagFilterRules.reconcile(
          available: <NewsTag>[tag('news')],
          selected: 'event',
        ),
        isNull,
      );
    });

    test('falls back to "Alle" when no tags are offered at all', () {
      expect(
        NewsTagFilterRules.reconcile(
          available: const <NewsTag>[],
          selected: 'event',
        ),
        isNull,
      );
    });
  });

  group('NewsTagFilterStorage', () {
    test('round-trips a selection', () async {
      final InMemoryKeyValueStore store = InMemoryKeyValueStore();
      final NewsTagFilterStorage storage = NewsTagFilterStorage(store);

      await storage.save('event');

      expect(storage.load(), 'event');
    });

    test('clearing removes the stored value', () async {
      final InMemoryKeyValueStore store = InMemoryKeyValueStore();
      final NewsTagFilterStorage storage = NewsTagFilterStorage(store);
      await storage.save('event');

      await storage.save(null);

      expect(storage.load(), isNull);
    });

    test('an empty store loads as "Alle"', () {
      expect(NewsTagFilterStorage(InMemoryKeyValueStore()).load(), isNull);
    });
  });

  group('NewsTagFilterController', () {
    test('starts on "Alle" with nothing stored', () {
      final ProviderContainer container = containerWith(
        InMemoryKeyValueStore(),
      );

      expect(container.read(newsTagFilterProvider), isNull);
    });

    test('a selection persists across a restart', () async {
      final InMemoryKeyValueStore store = InMemoryKeyValueStore();

      final ProviderContainer first = containerWith(store);
      await first.read(newsTagFilterProvider.notifier).select('event');
      first.dispose();

      final ProviderContainer second = containerWith(store);
      expect(second.read(newsTagFilterProvider), 'event');
    });

    test(
      'reconciling against a list without the selected tag resets to "Alle"',
      () async {
        final InMemoryKeyValueStore store = InMemoryKeyValueStore();
        final ProviderContainer container = containerWith(store);
        final NewsTagFilterController controller = container.read(
          newsTagFilterProvider.notifier,
        );
        await controller.select('event');

        await controller.reconcile(<NewsTag>[tag('news')]);

        expect(container.read(newsTagFilterProvider), isNull);
        expect(
          NewsTagFilterStorage(store).load(),
          isNull,
          reason: 'the reset must also be persisted, not just held in memory',
        );
      },
    );

    test(
      'reconciling against a list that still has the tag keeps it',
      () async {
        final ProviderContainer container = containerWith(
          InMemoryKeyValueStore(),
        );
        final NewsTagFilterController controller = container.read(
          newsTagFilterProvider.notifier,
        );
        await controller.select('event');

        await controller.reconcile(<NewsTag>[tag('event'), tag('news')]);

        expect(container.read(newsTagFilterProvider), 'event');
      },
    );
  });
}
