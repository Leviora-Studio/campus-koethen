// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/prefs/key_value_store.dart';
import '../../../core/prefs/preference_keys.dart';
import '../../../core/prefs/settings_controller.dart';

/// One selectable option in the event overview's source filter: a channel
/// (with its mapped calendar folded in, if any) or an unmapped calendar,
/// keyed by `UnifiedEvent.filterSourceKey`.
class EventSourceOption {
  const EventSourceOption({required this.key, required this.label});

  final String key;
  final String label;

  @override
  bool operator ==(Object other) =>
      other is EventSourceOption && other.key == key && other.label == label;

  @override
  int get hashCode => Object.hash(key, label);
}

/// Persisted multi-select state of the event overview's source filter.
///
/// Same seen/selected shape as [ChannelSubscriptionState] and
/// [PublicCalendarSelectionState] on purpose — same defaulting semantics —
/// but stored under its own preference keys, entirely separate from both.
class EventSourceFilterState {
  EventSourceFilterState({
    Set<String> seenKeys = const <String>{},
    Set<String> selectedKeys = const <String>{},
  }) : seenKeys = Set<String>.unmodifiable(seenKeys),
       selectedKeys = Set<String>.unmodifiable(selectedKeys);

  final Set<String> seenKeys;
  final Set<String> selectedKeys;

  static final EventSourceFilterState empty = EventSourceFilterState();

  bool isSelected(String key) => selectedKeys.contains(key);

  EventSourceFilterState copyWith({
    Set<String>? seenKeys,
    Set<String>? selectedKeys,
  }) => EventSourceFilterState(
    seenKeys: seenKeys ?? this.seenKeys,
    selectedKeys: selectedKeys ?? this.selectedKeys,
  );

  @override
  bool operator ==(Object other) =>
      other is EventSourceFilterState &&
      _sameSet(other.seenKeys, seenKeys) &&
      _sameSet(other.selectedKeys, selectedKeys);

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered(seenKeys),
    Object.hashAllUnordered(selectedKeys),
  );

  static bool _sameSet(Set<String> a, Set<String> b) =>
      a.length == b.length && a.containsAll(b);
}

/// Pure filter rules, free of storage and Riverpod — mirrors
/// `PublicCalendarSelectionRules`/`ChannelSubscriptionRules` exactly.
abstract final class EventSourceFilterRules {
  /// Folds the currently available [options] into the stored state.
  ///
  /// First-ever use (an empty [EventSourceFilterState.seenKeys]) selects
  /// every currently available option — "Erstnutzung: alle aktuell
  /// verfügbaren Eventquellen ausgewählt". After that, only a genuinely new
  /// key (never seen before) is added to the selection; an option the reader
  /// deliberately deselected stays off no matter what else appears.
  ///
  /// An empty [options] list leaves the state untouched — a temporarily
  /// empty catalogue must never wipe the user's preferences.
  static EventSourceFilterState reconcile(
    EventSourceFilterState current,
    List<EventSourceOption> options,
  ) {
    if (options.isEmpty) return current;

    final bool isFirstUse = current.seenKeys.isEmpty;
    final Set<String> available = options
        .map((EventSourceOption o) => o.key)
        .toSet();

    final Set<String> seen = <String>{...current.seenKeys};
    final Set<String> selected = <String>{...current.selectedKeys};

    for (final EventSourceOption option in options) {
      final bool firstAppearance = seen.add(option.key);
      if (isFirstUse || firstAppearance) selected.add(option.key);
    }
    selected.retainAll(available);

    return EventSourceFilterState(seenKeys: seen, selectedKeys: selected);
  }

  /// The selected keys that actually exist among [available], as a set.
  static Set<String> effectiveSelection({
    required List<EventSourceOption> available,
    required Set<String> selected,
  }) {
    final Set<String> availableKeys = available
        .map((EventSourceOption o) => o.key)
        .toSet();
    return selected.intersection(availableKeys);
  }
}

class EventSourceFilterStorage {
  const EventSourceFilterStorage(this._store);

  final KeyValueStore _store;

  EventSourceFilterState load() {
    final int version =
        _store.getInt(PreferenceKeys.eventSourceStoreVersion) ?? 0;
    if (version != PreferenceKeys.eventSourceStoreCurrentVersion) {
      return EventSourceFilterState.empty;
    }
    return EventSourceFilterState(
      seenKeys:
          _store.getStringList(PreferenceKeys.eventSourceSeenKeys)?.toSet() ??
          const <String>{},
      selectedKeys:
          _store
              .getStringList(PreferenceKeys.eventSourceSelectedKeys)
              ?.toSet() ??
          const <String>{},
    );
  }

  Future<void> save(EventSourceFilterState state) async {
    await _store.setInt(
      PreferenceKeys.eventSourceStoreVersion,
      PreferenceKeys.eventSourceStoreCurrentVersion,
    );
    await _store.setStringList(
      PreferenceKeys.eventSourceSeenKeys,
      List<String>.of(state.seenKeys)..sort(),
    );
    await _store.setStringList(
      PreferenceKeys.eventSourceSelectedKeys,
      List<String>.of(state.selectedKeys)..sort(),
    );
  }
}

class EventSourceFilterController extends Notifier<EventSourceFilterState> {
  late EventSourceFilterStorage _storage;

  @override
  EventSourceFilterState build() {
    _storage = EventSourceFilterStorage(ref.watch(keyValueStoreProvider));
    return _storage.load();
  }

  Future<EventSourceFilterState> reconcile(
    List<EventSourceOption> options,
  ) async {
    final EventSourceFilterState next = EventSourceFilterRules.reconcile(
      state,
      options,
    );
    if (next == state) return state;
    state = next;
    await _storage.save(next);
    return next;
  }

  Future<void> setSelected(String key, {required bool selected}) async {
    final Set<String> next = <String>{...state.selectedKeys};
    if (selected) {
      next.add(key);
    } else {
      next.remove(key);
    }
    final EventSourceFilterState updated = state.copyWith(
      seenKeys: <String>{...state.seenKeys, key},
      selectedKeys: next,
    );
    state = updated;
    await _storage.save(updated);
  }
}

final NotifierProvider<EventSourceFilterController, EventSourceFilterState>
eventSourceFilterProvider =
    NotifierProvider<EventSourceFilterController, EventSourceFilterState>(
      EventSourceFilterController.new,
    );
