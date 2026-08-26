// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/prefs/key_value_store.dart';
import '../../../core/prefs/preference_keys.dart';
import '../../../core/prefs/settings_controller.dart';
import '../domain/public_calendar.dart';

/// Persisted "Y of X" selection of public calendars — a non-sensitive local
/// preference, so SharedPreferences is appropriate.
///
/// Same two-set design as the news channel subscription: [seenSlugs] is an
/// append-only ledger that makes `defaultSubscribed` apply exactly once per
/// slug; [selectedSlugs] is the user's current selection, pruned to what the
/// catalogue currently offers.
class PublicCalendarSelectionState {
  PublicCalendarSelectionState({
    Set<String> seenSlugs = const <String>{},
    Set<String> selectedSlugs = const <String>{},
  }) : seenSlugs = Set<String>.unmodifiable(seenSlugs),
       selectedSlugs = Set<String>.unmodifiable(selectedSlugs);

  final Set<String> seenSlugs;
  final Set<String> selectedSlugs;

  static final PublicCalendarSelectionState empty =
      PublicCalendarSelectionState();

  bool isSelected(String slug) => selectedSlugs.contains(slug);

  PublicCalendarSelectionState copyWith({
    Set<String>? seenSlugs,
    Set<String>? selectedSlugs,
  }) {
    return PublicCalendarSelectionState(
      seenSlugs: seenSlugs ?? this.seenSlugs,
      selectedSlugs: selectedSlugs ?? this.selectedSlugs,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is PublicCalendarSelectionState &&
      _sameSet(other.seenSlugs, seenSlugs) &&
      _sameSet(other.selectedSlugs, selectedSlugs);

  @override
  int get hashCode => Object.hash(
    Object.hashAllUnordered(seenSlugs),
    Object.hashAllUnordered(selectedSlugs),
  );

  static bool _sameSet(Set<String> a, Set<String> b) =>
      a.length == b.length && a.containsAll(b);
}

/// Pure selection rules, free of storage and Riverpod.
abstract final class PublicCalendarSelectionRules {
  /// Folds a freshly fetched catalogue into the stored selection.
  ///
  /// A never-seen slug adopts its `defaultSubscribed` value (once); a
  /// deliberately deselected slug stays off; vanished slugs are pruned from the
  /// selection but kept in [seenSlugs]. An EMPTY catalogue leaves the state
  /// untouched — a temporarily unavailable catalogue must not wipe preferences.
  static PublicCalendarSelectionState reconcile(
    PublicCalendarSelectionState current,
    List<PublicCalendar> calendars,
  ) {
    if (calendars.isEmpty) return current;

    final Set<String> available = calendars
        .map((PublicCalendar c) => c.slug)
        .toSet();
    final Set<String> seen = <String>{...current.seenSlugs};
    final Set<String> selected = <String>{...current.selectedSlugs};

    for (final PublicCalendar c in calendars) {
      final bool firstAppearance = seen.add(c.slug);
      if (firstAppearance && c.defaultSubscribed) selected.add(c.slug);
    }
    selected.retainAll(available);

    return PublicCalendarSelectionState(
      seenSlugs: seen,
      selectedSlugs: selected,
    );
  }

  /// The selected slugs that actually exist in the catalogue, sorted.
  static List<String> effectiveSelection({
    required List<PublicCalendar> available,
    required Set<String> selected,
  }) {
    return available
        .map((PublicCalendar c) => c.slug)
        .where(selected.contains)
        .toList(growable: false)
      ..sort();
  }
}

class PublicCalendarSelectionStorage {
  const PublicCalendarSelectionStorage(this._store);

  final KeyValueStore _store;

  PublicCalendarSelectionState load() {
    final int version =
        _store.getInt(PreferenceKeys.publicCalendarStoreVersion) ?? 0;
    if (version != PreferenceKeys.publicCalendarStoreCurrentVersion) {
      return PublicCalendarSelectionState.empty;
    }
    return PublicCalendarSelectionState(
      seenSlugs:
          _store
              .getStringList(PreferenceKeys.publicCalendarSeenSlugs)
              ?.toSet() ??
          const <String>{},
      selectedSlugs:
          _store
              .getStringList(PreferenceKeys.publicCalendarSelectedSlugs)
              ?.toSet() ??
          const <String>{},
    );
  }

  Future<void> save(PublicCalendarSelectionState state) async {
    await _store.setInt(
      PreferenceKeys.publicCalendarStoreVersion,
      PreferenceKeys.publicCalendarStoreCurrentVersion,
    );
    await _store.setStringList(
      PreferenceKeys.publicCalendarSeenSlugs,
      List<String>.of(state.seenSlugs)..sort(),
    );
    await _store.setStringList(
      PreferenceKeys.publicCalendarSelectedSlugs,
      List<String>.of(state.selectedSlugs)..sort(),
    );
  }
}

class PublicCalendarSelectionController
    extends Notifier<PublicCalendarSelectionState> {
  late PublicCalendarSelectionStorage _storage;

  @override
  PublicCalendarSelectionState build() {
    _storage = PublicCalendarSelectionStorage(ref.watch(keyValueStoreProvider));
    return _storage.load();
  }

  Future<PublicCalendarSelectionState> reconcile(
    List<PublicCalendar> calendars,
  ) async {
    final PublicCalendarSelectionState next =
        PublicCalendarSelectionRules.reconcile(state, calendars);
    if (next == state) return state;
    state = next;
    await _storage.save(next);
    return next;
  }

  Future<void> setSelected(String slug, {required bool selected}) async {
    final Set<String> next = <String>{...state.selectedSlugs};
    if (selected) {
      next.add(slug);
    } else {
      next.remove(slug);
    }
    final PublicCalendarSelectionState updated = state.copyWith(
      seenSlugs: <String>{...state.seenSlugs, slug},
      selectedSlugs: next,
    );
    state = updated;
    await _storage.save(updated);
  }
}

final NotifierProvider<
  PublicCalendarSelectionController,
  PublicCalendarSelectionState
>
publicCalendarSelectionProvider =
    NotifierProvider<
      PublicCalendarSelectionController,
      PublicCalendarSelectionState
    >(PublicCalendarSelectionController.new);
