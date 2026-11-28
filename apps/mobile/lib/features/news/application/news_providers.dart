// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/locale/locale_providers.dart';
import '../../../core/network/loaded.dart';
import '../data/news_models.dart';
import '../data/news_repository.dart';
import 'channel_subscriptions.dart';
import 'tag_filter.dart';

/// The full channel list. Also the single place where `defaultSubscribed` is
/// folded into the local subscription store.
final FutureProvider<Loaded<List<NewsChannel>>> newsChannelsProvider =
    FutureProvider<Loaded<List<NewsChannel>>>((Ref ref) async {
      final String locale = ref.watch(localeCodeProvider);
      final Loaded<List<NewsChannel>> loaded = await ref
          .watch(newsRepositoryProvider)
          .fetchChannels(locale: locale);
      await ref
          .read(channelSubscriptionProvider.notifier)
          .reconcile(loaded.value);
      return loaded;
    }, retry: (_, _) => null);

/// Joins the feed's lightweight channel references to the channel catalogue.
final newsChannelLocationNamesProvider = Provider<Map<String, String>>((ref) {
  final channels = ref.watch(newsChannelsProvider).value?.value ?? [];
  return {
    for (final channel in channels)
      if (channel.location case final location?) channel.slug: location.name,
  };
});

/// The full active tag list. Also the single place where a removed or
/// deactivated tag prunes a stale persisted filter selection.
final FutureProvider<Loaded<List<NewsTag>>> newsTagsProvider =
    FutureProvider<Loaded<List<NewsTag>>>((Ref ref) async {
      final String locale = ref.watch(localeCodeProvider);
      final Loaded<List<NewsTag>> loaded = await ref
          .watch(newsRepositoryProvider)
          .fetchTags(locale: locale);
      await ref.read(newsTagFilterProvider.notifier).reconcile(loaded.value);
      return loaded;
    });

class NewsLocationFilter extends Notifier<String?> {
  @override
  String? build() => null;

  void select(String? slug) => state = slug;
}

final newsLocationFilterProvider =
    NotifierProvider<NewsLocationFilter, String?>(NewsLocationFilter.new);
