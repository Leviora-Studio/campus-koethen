// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/saved_events_store.dart';
import '../domain/saved_event_snapshot.dart';
import '../domain/saved_events_rules.dart';
import '../domain/unified_event.dart';

/// Riverpod front end of [SavedEventsStore], applying the cap, orphan and
/// retention rules from `saved_events_rules.dart` around plain persistence.
class SavedEventsController extends AsyncNotifier<List<SavedEventSnapshot>> {
  SavedEventsStore get _store => ref.read(savedEventsStoreProvider);
  DateTime Function() get _now => ref.read(savedEventsClockProvider);

  @override
  Future<List<SavedEventSnapshot>> build() async {
    final List<SavedEventSnapshot> loaded = await _store.readAll();
    // The 365-day cleanup runs opportunistically on every load — no
    // background job is needed for a locally-owned list this small.
    final List<SavedEventSnapshot> pruned = pruneExpiredSavedEvents(
      loaded,
      now: _now(),
    );
    if (pruned.length != loaded.length) await _store.writeAll(pruned);
    return pruned;
  }

  /// Saves [event]. Silently declines once the 500-entry cap is reached
  /// (returns `false`) rather than evicting anything — the cap is a limit,
  /// not a rotation policy the user did not ask for.
  Future<bool> save(UnifiedEvent event) async {
    final List<SavedEventSnapshot> current =
        state.value ?? const <SavedEventSnapshot>[];
    if (current.any((SavedEventSnapshot s) => s.eventRef == event.eventRef)) {
      return true; // already saved
    }
    if (!canAddSavedEvent(current)) return false;

    final List<SavedEventSnapshot> next = <SavedEventSnapshot>[
      ...current,
      SavedEventSnapshot.fromUnifiedEvent(event, savedAt: _now()),
    ];
    state = AsyncData<List<SavedEventSnapshot>>(next);
    await _store.writeAll(next);
    return true;
  }

  /// Explicit user removal — the only removal path besides the automatic
  /// 365-day-after-end cleanup.
  Future<void> remove(String eventRef) async {
    final List<SavedEventSnapshot> current =
        state.value ?? const <SavedEventSnapshot>[];
    final List<SavedEventSnapshot> next = current
        .where((SavedEventSnapshot s) => s.eventRef != eventRef)
        .toList();
    if (next.length == current.length) return;
    state = AsyncData<List<SavedEventSnapshot>>(next);
    await _store.writeAll(next);
  }

  /// Whether [eventRef] is on the list.
  ///
  /// A linear scan, which is fine for the one-off question an action asks.
  /// A widget that renders many events asks [savedEventRefsProvider] instead —
  /// see its doc comment.
  bool isSaved(String eventRef) => (state.value ?? const <SavedEventSnapshot>[])
      .any((SavedEventSnapshot s) => s.eventRef == eventRef);

  /// Applies the orphan rule after a **successful** load of one source's
  /// window — never call this from an error/timeout/offline handler.
  ///
  /// [loadedEventRefs] are the `eventRef`s the load actually returned; only
  /// the identity is needed for the orphan check, not the full events.
  Future<void> reconcileAfterSuccessfulLoad({
    required Iterable<String> loadedEventRefs,
    required DateTime windowFrom,
    required DateTime windowTo,
    required bool Function(SavedEventSnapshot snapshot) belongsToThisSource,
  }) async {
    final List<SavedEventSnapshot> current =
        state.value ?? const <SavedEventSnapshot>[];
    if (current.isEmpty) return;
    final Set<String> loadedRefs = loadedEventRefs.toSet();
    final List<SavedEventSnapshot> next = reconcileOrphanStatus(
      saved: current,
      loadedEventRefs: loadedRefs,
      windowFrom: windowFrom,
      windowTo: windowTo,
      belongsToThisSource: belongsToThisSource,
    );
    final bool changed = List.generate(
      next.length,
      (int i) => next[i].isOrphaned != current[i].isOrphaned,
    ).any((bool b) => b);
    if (!changed) return;
    state = AsyncData<List<SavedEventSnapshot>>(next);
    await _store.writeAll(next);
  }

  /// The two deterministic display groups.
  SavedEventsGroups groups({DateTime? now}) => groupSavedEvents(
    state.value ?? const <SavedEventSnapshot>[],
    now: now ?? _now(),
  );
}

final AsyncNotifierProvider<SavedEventsController, List<SavedEventSnapshot>>
savedEventsControllerProvider =
    AsyncNotifierProvider<SavedEventsController, List<SavedEventSnapshot>>(
      SavedEventsController.new,
    );

/// Which events are on the saved list, as a set of their `eventRef`s.
///
/// An event card asks one question: "is THIS event saved". Answering it from
/// the list itself meant two costs on a screen full of cards. Watching the
/// list rebuilt every visible card whenever any event anywhere was saved or
/// unsaved, and the answer itself was a linear scan of a list the cap allows
/// to hold [kSavedEventsCap] entries — so n cards paid n × 500 comparisons.
///
/// Derived here once per change, so a card can `select` the single boolean it
/// cares about: it then rebuilds only when its own state changes, and the
/// lookup is a set membership test.
final Provider<Set<String>> savedEventRefsProvider = Provider<Set<String>>((
  Ref ref,
) {
  final List<SavedEventSnapshot> saved =
      ref.watch(savedEventsControllerProvider).value ??
      const <SavedEventSnapshot>[];
  return <String>{
    for (final SavedEventSnapshot snapshot in saved) snapshot.eventRef,
  };
});

/// Overridable clock, so tests can control "now" for the retention/orphan
/// rules without depending on the wall clock.
final Provider<DateTime Function()> savedEventsClockProvider =
    Provider<DateTime Function()>((Ref ref) => DateTime.now);

/// Overridable store, same convention as `todoStoreProvider`: the default is
/// the real Hive-backed store, and tests override with
/// [MemorySavedEventsStore].
final Provider<SavedEventsStore> savedEventsStoreProvider =
    Provider<SavedEventsStore>((Ref ref) => HiveSavedEventsStore());
