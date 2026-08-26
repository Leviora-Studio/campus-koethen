// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:campus_koethen/core/prefs/key_value_store.dart';
import 'package:campus_koethen/core/prefs/preference_keys.dart';
import 'package:campus_koethen/core/prefs/settings_controller.dart';
import 'package:campus_koethen/features/news/application/channel_subscriptions.dart';
import 'package:campus_koethen/features/news/data/news_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

NewsChannel channel(
  String slug, {
  bool defaultSubscribed = false,
  int sortOrder = 0,
}) => NewsChannel(
  slug: slug,
  name: slug,
  sortOrder: sortOrder,
  defaultSubscribed: defaultSubscribed,
);

ProviderContainer containerWith(KeyValueStore store) {
  final ProviderContainer container = ProviderContainer(
    overrides: <Override>[keyValueStoreProvider.overrideWithValue(store)],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('ChannelSubscriptionRules.reconcile', () {
    test('applies defaultSubscribed on a slug\'s first ever appearance', () {
      final ChannelSubscriptionState state = ChannelSubscriptionRules.reconcile(
        ChannelSubscriptionState.empty,
        <NewsChannel>[
          channel('campus-news', defaultSubscribed: true),
          channel('fb5-news', defaultSubscribed: true),
          channel('quiet-channel'),
        ],
      );

      expect(state.selectedSlugs, <String>{'campus-news', 'fb5-news'});
      expect(state.seenSlugs, <String>{
        'campus-news',
        'fb5-news',
        'quiet-channel',
      });
    });

    test('never re-applies the default after the first appearance', () {
      ChannelSubscriptionState state = ChannelSubscriptionRules.reconcile(
        ChannelSubscriptionState.empty,
        <NewsChannel>[channel('campus-news', defaultSubscribed: true)],
      );
      expect(state.selectedSlugs, <String>{'campus-news'});

      // The user deselects it.
      state = state.copyWith(selectedSlugs: const <String>{});

      // The very same channel is fetched again, still defaultSubscribed.
      state = ChannelSubscriptionRules.reconcile(state, <NewsChannel>[
        channel('campus-news', defaultSubscribed: true),
      ]);

      expect(
        state.selectedSlugs,
        isEmpty,
        reason: 'a deliberate deselection outranks the default',
      );
    });

    test('a new default channel does not resurrect a deselected one', () {
      ChannelSubscriptionState state = ChannelSubscriptionRules.reconcile(
        ChannelSubscriptionState.empty,
        <NewsChannel>[channel('campus-news', defaultSubscribed: true)],
      );
      state = state.copyWith(selectedSlugs: const <String>{});

      state = ChannelSubscriptionRules.reconcile(state, <NewsChannel>[
        channel('campus-news', defaultSubscribed: true),
        channel('fb5-news', defaultSubscribed: true),
      ]);

      expect(state.selectedSlugs, <String>{'fb5-news'});
    });

    test('prunes slugs that disappeared from the API', () {
      ChannelSubscriptionState state = ChannelSubscriptionRules.reconcile(
        ChannelSubscriptionState.empty,
        <NewsChannel>[
          channel('campus-news', defaultSubscribed: true),
          channel('fb5-news', defaultSubscribed: true),
        ],
      );
      expect(state.selectedSlugs, hasLength(2));

      state = ChannelSubscriptionRules.reconcile(state, <NewsChannel>[
        channel('campus-news', defaultSubscribed: true),
      ]);

      expect(state.selectedSlugs, <String>{'campus-news'});
      expect(
        state.seenSlugs,
        contains('fb5-news'),
        reason: 'the ledger is kept so the default is not re-applied later',
      );
    });

    test('an empty channel list never wipes the stored selection', () {
      final ChannelSubscriptionState state = ChannelSubscriptionRules.reconcile(
        ChannelSubscriptionState(
          seenSlugs: const <String>{'campus-news'},
          selectedSlugs: const <String>{'campus-news'},
        ),
        const <NewsChannel>[],
      );

      expect(state.selectedSlugs, <String>{'campus-news'});
    });

    test('tolerates a channel reappearing without re-applying its default', () {
      ChannelSubscriptionState state = ChannelSubscriptionRules.reconcile(
        ChannelSubscriptionState.empty,
        <NewsChannel>[channel('temp', defaultSubscribed: true)],
      );
      state = state.copyWith(selectedSlugs: const <String>{});
      // Channel disappears entirely …
      state = ChannelSubscriptionRules.reconcile(state, <NewsChannel>[
        channel('other'),
      ]);
      // … and comes back.
      state = ChannelSubscriptionRules.reconcile(state, <NewsChannel>[
        channel('temp', defaultSubscribed: true),
        channel('other'),
      ]);

      expect(state.selectedSlugs, isEmpty);
    });
  });

  group('ChannelSubscriptionRules.queryValue', () {
    test('omits the parameter while no channel is known', () {
      expect(
        ChannelSubscriptionRules.queryValue(
          available: const <NewsChannel>[],
          selected: const <String>{},
        ),
        isNull,
      );
    });

    test('sends a present-but-empty value when everything is deselected', () {
      expect(
        ChannelSubscriptionRules.queryValue(
          available: <NewsChannel>[channel('campus-news'), channel('fb5-news')],
          selected: const <String>{},
        ),
        '',
      );
    });

    test('sends a deterministic CSV of the selected slugs', () {
      expect(
        ChannelSubscriptionRules.queryValue(
          available: <NewsChannel>[channel('fb5-news'), channel('campus-news')],
          selected: const <String>{'fb5-news', 'campus-news'},
        ),
        'campus-news,fb5-news',
      );
    });

    test('ignores selected slugs that are no longer offered', () {
      expect(
        ChannelSubscriptionRules.queryValue(
          available: <NewsChannel>[channel('campus-news')],
          selected: const <String>{'campus-news', 'gone'},
        ),
        'campus-news',
      );
    });
  });

  group('ChannelSubscriptionStorage', () {
    test('round-trips a state', () async {
      final InMemoryKeyValueStore store = InMemoryKeyValueStore();
      final ChannelSubscriptionStorage storage = ChannelSubscriptionStorage(
        store,
      );

      await storage.save(
        ChannelSubscriptionState(
          seenSlugs: const <String>{'a', 'b'},
          selectedSlugs: const <String>{'a'},
        ),
      );

      final ChannelSubscriptionState loaded = storage.load();
      expect(loaded.seenSlugs, <String>{'a', 'b'});
      expect(loaded.selectedSlugs, <String>{'a'});
    });

    test('discards a payload written by an unknown store version', () async {
      final InMemoryKeyValueStore store = InMemoryKeyValueStore();
      await store.setInt(PreferenceKeys.channelStoreVersion, 999);
      await store.setStringList(PreferenceKeys.channelSeenSlugs, <String>['a']);
      await store.setStringList(PreferenceKeys.channelSelectedSlugs, <String>[
        'a',
      ]);

      expect(
        ChannelSubscriptionStorage(store).load(),
        ChannelSubscriptionState.empty,
      );
    });

    test('tolerates a completely empty store', () {
      expect(
        ChannelSubscriptionStorage(InMemoryKeyValueStore()).load(),
        ChannelSubscriptionState.empty,
      );
    });
  });

  group('ChannelSubscriptionController', () {
    test('persists a deselection across a restart', () async {
      final InMemoryKeyValueStore store = InMemoryKeyValueStore();

      final ProviderContainer first = containerWith(store);
      await first
          .read(channelSubscriptionProvider.notifier)
          .reconcile(<NewsChannel>[
            channel('campus-news', defaultSubscribed: true),
            channel('fb5-news', defaultSubscribed: true),
          ]);
      await first
          .read(channelSubscriptionProvider.notifier)
          .setSubscribed('fb5-news', subscribed: false);
      first.dispose();

      // "Restart": a fresh container reading the same store.
      final ProviderContainer second = containerWith(store);
      expect(second.read(channelSubscriptionProvider).selectedSlugs, <String>{
        'campus-news',
      });

      // A later fetch must not bring the deselected channel back.
      await second
          .read(channelSubscriptionProvider.notifier)
          .reconcile(<NewsChannel>[
            channel('campus-news', defaultSubscribed: true),
            channel('fb5-news', defaultSubscribed: true),
          ]);
      expect(second.read(channelSubscriptionProvider).selectedSlugs, <String>{
        'campus-news',
      });
    });

    test('supports deselecting every channel', () async {
      final InMemoryKeyValueStore store = InMemoryKeyValueStore();
      final ProviderContainer container = containerWith(store);
      final ChannelSubscriptionController controller = container.read(
        channelSubscriptionProvider.notifier,
      );

      await controller.reconcile(<NewsChannel>[
        channel('campus-news', defaultSubscribed: true),
      ]);
      await controller.setSubscribed('campus-news', subscribed: false);

      expect(
        container.read(channelSubscriptionProvider).selectedSlugs,
        isEmpty,
      );
      expect(
        ChannelSubscriptionRules.queryValue(
          available: <NewsChannel>[channel('campus-news')],
          selected: container.read(channelSubscriptionProvider).selectedSlugs,
        ),
        '',
        reason: 'the parameter must be present but empty, never omitted',
      );
    });
  });
}
