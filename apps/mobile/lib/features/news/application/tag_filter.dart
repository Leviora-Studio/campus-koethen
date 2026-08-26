// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/prefs/key_value_store.dart';
import '../../../core/prefs/preference_keys.dart';
import '../../../core/prefs/settings_controller.dart';
import '../data/news_models.dart';

/// The pure tag-filter rules, free of storage and Riverpod.
///
/// Kept separate so the contract can be tested exhaustively, same as
/// `ChannelSubscriptionRules`.
abstract final class NewsTagFilterRules {
  /// Resolves a persisted [selected] slug against the currently [available]
  /// active tags.
  ///
  /// A tag that is no longer offered — removed or deactivated in the CMS —
  /// must fall back to `null` ("Alle") rather than silently keep filtering
  /// on a slug the API no longer recognises, which would otherwise look
  /// exactly like "no articles" with no way out for the reader.
  static String? reconcile({
    required List<NewsTag> available,
    required String? selected,
  }) {
    if (selected == null) return null;
    final bool stillOffered = available.any(
      (NewsTag tag) => tag.slug == selected,
    );
    return stillOffered ? selected : null;
  }
}

/// Loads and stores the selected tag filter in `shared_preferences`.
///
/// A single scalar, not the seen/selected pair channels use: a tag filter is
/// a content view the reader dips in and out of, not a standing
/// subscription, so there is no default-on behaviour to guard.
class NewsTagFilterStorage {
  const NewsTagFilterStorage(this._store);

  final KeyValueStore _store;

  String? load() => _store.getString(PreferenceKeys.newsTagFilterSelected);

  Future<void> save(String? slug) async {
    if (slug == null) {
      await _store.remove(PreferenceKeys.newsTagFilterSelected);
    } else {
      await _store.setString(PreferenceKeys.newsTagFilterSelected, slug);
    }
  }
}

/// Riverpod front end of the tag filter: the single tag slug the feed
/// currently filters by, or `null` for "Alle".
class NewsTagFilterController extends Notifier<String?> {
  late NewsTagFilterStorage _storage;

  @override
  String? build() {
    _storage = NewsTagFilterStorage(ref.watch(keyValueStoreProvider));
    return _storage.load();
  }

  /// Selects a tag, or `null` to reset to "Alle".
  Future<void> select(String? slug) async {
    if (slug == state) return;
    state = slug;
    await _storage.save(slug);
  }

  /// Applies a freshly fetched tag list, resetting to "Alle" when the
  /// currently selected tag has been removed or deactivated.
  Future<void> reconcile(List<NewsTag> tags) async {
    final String? next = NewsTagFilterRules.reconcile(
      available: tags,
      selected: state,
    );
    if (next == state) return;
    state = next;
    await _storage.save(next);
  }
}

final NotifierProvider<NewsTagFilterController, String?> newsTagFilterProvider =
    NotifierProvider<NewsTagFilterController, String?>(
      NewsTagFilterController.new,
    );
