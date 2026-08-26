// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/prefs/key_value_store.dart';
import '../../../core/prefs/preference_keys.dart';
import '../../../core/prefs/settings_controller.dart';
import '../data/news_models.dart';

/// Persisted state of the news channel subscriptions.
///
/// Two sets, with deliberately different lifetimes:
///
/// * [seenSlugs] is an **append-only ledger** of every channel slug the app has
///   ever encountered. It is what makes `defaultSubscribed` apply *exactly
///   once* per slug — even if the channel later disappears and comes back.
/// * [selectedSlugs] is the user's current subscription. It is pruned to the
///   channels the API currently offers so a vanished slug is never sent.
class ChannelSubscriptionState {
  ChannelSubscriptionState({
    Set<String> seenSlugs = const <String>{},
    Set<String> selectedSlugs = const <String>{},
  }) : seenSlugs = Set<String>.unmodifiable(seenSlugs),
       selectedSlugs = Set<String>.unmodifiable(selectedSlugs);

  final Set<String> seenSlugs;
  final Set<String> selectedSlugs;

  static final ChannelSubscriptionState empty = ChannelSubscriptionState();

  bool isSubscribed(String slug) => selectedSlugs.contains(slug);

  ChannelSubscriptionState copyWith({
    Set<String>? seenSlugs,
    Set<String>? selectedSlugs,
  }) {
    return ChannelSubscriptionState(
      seenSlugs: seenSlugs ?? this.seenSlugs,
      selectedSlugs: selectedSlugs ?? this.selectedSlugs,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ChannelSubscriptionState &&
      _sameSet(other.seenSlugs, seenSlugs) &&
      _sameSet(other.selectedSlugs, selectedSlugs);

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered(seenSlugs),
    Object.hashAllUnordered(selectedSlugs),
  );

  static bool _sameSet(Set<String> a, Set<String> b) =>
      a.length == b.length && a.containsAll(b);

  @override
  String toString() =>
      'ChannelSubscriptionState(seen: ${_sorted(seenSlugs)}, '
      'selected: ${_sorted(selectedSlugs)})';

  static List<String> _sorted(Set<String> value) =>
      List<String>.of(value)..sort();
}

/// The pure subscription rules, free of storage and Riverpod.
///
/// Kept separate so the contract can be tested exhaustively.
abstract final class ChannelSubscriptionRules {
  /// Folds a freshly fetched channel list into the stored state.
  ///
  /// * A slug that has never been seen adopts its `defaultSubscribed` value and
  ///   is recorded as seen, so the default is never applied a second time.
  /// * A slug the user deselected stays deselected, no matter which other
  ///   channels appear later.
  /// * Slugs that are no longer offered are pruned from the selection.
  ///
  /// An **empty** [channels] list is treated as "nothing to reconcile" and
  /// leaves the state untouched: an empty API answer must never wipe the user's
  /// preferences.
  static ChannelSubscriptionState reconcile(
    ChannelSubscriptionState current,
    List<NewsChannel> channels,
  ) {
    if (channels.isEmpty) return current;

    final Set<String> available = channels
        .map((NewsChannel channel) => channel.slug)
        .toSet();

    final Set<String> seen = <String>{...current.seenSlugs};
    final Set<String> selected = <String>{...current.selectedSlugs};

    for (final NewsChannel channel in channels) {
      final bool firstAppearance = seen.add(channel.slug);
      if (firstAppearance && channel.defaultSubscribed) {
        selected.add(channel.slug);
      }
    }

    selected.retainAll(available);

    return ChannelSubscriptionState(seenSlugs: seen, selectedSlugs: selected);
  }

  /// The value of the `channels` query parameter.
  ///
  /// * `null` — the parameter is **omitted**, meaning "all active channels".
  ///   Only used while the channel list is still unknown.
  /// * `''` — the parameter is **present but empty**, meaning "deliberately no
  ///   channels". This is what the app sends when the user deselected
  ///   everything; omitting it there would silently load all news.
  static String? queryValue({
    required List<NewsChannel> available,
    required Set<String> selected,
  }) {
    if (available.isEmpty) return null;
    final List<String> slugs =
        available
            .map((NewsChannel channel) => channel.slug)
            .where(selected.contains)
            .toList(growable: false)
          ..sort();
    return slugs.join(',');
  }
}

/// Loads and stores [ChannelSubscriptionState] in `shared_preferences`.
///
/// The store is versioned: a version mismatch discards the old payload instead
/// of trying to migrate an unknown shape.
class ChannelSubscriptionStorage {
  const ChannelSubscriptionStorage(this._store);

  final KeyValueStore _store;

  ChannelSubscriptionState load() {
    final int version = _store.getInt(PreferenceKeys.channelStoreVersion) ?? 0;
    if (version != PreferenceKeys.channelStoreCurrentVersion) {
      return ChannelSubscriptionState.empty;
    }
    return ChannelSubscriptionState(
      seenSlugs:
          _store.getStringList(PreferenceKeys.channelSeenSlugs)?.toSet() ??
          const <String>{},
      selectedSlugs:
          _store.getStringList(PreferenceKeys.channelSelectedSlugs)?.toSet() ??
          const <String>{},
    );
  }

  Future<void> save(ChannelSubscriptionState state) async {
    await _store.setInt(
      PreferenceKeys.channelStoreVersion,
      PreferenceKeys.channelStoreCurrentVersion,
    );
    await _store.setStringList(
      PreferenceKeys.channelSeenSlugs,
      List<String>.of(state.seenSlugs)..sort(),
    );
    await _store.setStringList(
      PreferenceKeys.channelSelectedSlugs,
      List<String>.of(state.selectedSlugs)..sort(),
    );
  }
}

/// Riverpod front end of the subscription store.
class ChannelSubscriptionController extends Notifier<ChannelSubscriptionState> {
  late ChannelSubscriptionStorage _storage;

  @override
  ChannelSubscriptionState build() {
    _storage = ChannelSubscriptionStorage(ref.watch(keyValueStoreProvider));
    return _storage.load();
  }

  /// Applies a freshly fetched channel list. Returns the resulting state.
  Future<ChannelSubscriptionState> reconcile(List<NewsChannel> channels) async {
    final ChannelSubscriptionState next = ChannelSubscriptionRules.reconcile(
      state,
      channels,
    );
    if (next == state) return state;
    state = next;
    await _storage.save(next);
    return next;
  }

  Future<void> setSubscribed(String slug, {required bool subscribed}) async {
    final Set<String> selected = <String>{...state.selectedSlugs};
    if (subscribed) {
      selected.add(slug);
    } else {
      selected.remove(slug);
    }
    final ChannelSubscriptionState next = state.copyWith(
      seenSlugs: <String>{...state.seenSlugs, slug},
      selectedSlugs: selected,
    );
    state = next;
    await _storage.save(next);
  }
}

final NotifierProvider<ChannelSubscriptionController, ChannelSubscriptionState>
channelSubscriptionProvider =
    NotifierProvider<ChannelSubscriptionController, ChannelSubscriptionState>(
      ChannelSubscriptionController.new,
    );
