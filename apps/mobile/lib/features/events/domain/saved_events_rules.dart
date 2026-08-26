// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'saved_event_snapshot.dart';

/// Maximum number of entries the saved-events list keeps.
const int kSavedEventsCap = 500;

/// How long a saved event survives past its end before automatic cleanup.
const Duration kSavedEventsRetention = Duration(days: 365);

/// Whether a new entry may be added without exceeding [kSavedEventsCap].
bool canAddSavedEvent(
  List<SavedEventSnapshot> current, {
  int cap = kSavedEventsCap,
}) => current.length < cap;

/// Reconciles orphan status after a **successful** load of one source's
/// window.
///
/// Only a snapshot that [belongsToThisSource] AND whose start falls strictly
/// within `[windowFrom, windowTo)` is touched — that is precisely "dessen
/// Start im tatsächlich angefragten Fenster liegt". A snapshot outside the
/// window, or belonging to a different source, is left exactly as it was.
/// The upper bound is exclusive so a start sitting exactly on the window's
/// edge is never treated as "covered" by this call — "kein bloßer
/// Fensterrand".
///
/// This function must only ever be called from a successful response
/// handler: a failed request, a timeout, or being offline must never call it,
/// which is what keeps the orphan flag from ever being set by anything other
/// than a genuine "this event is missing from a response that should have
/// had it".
List<SavedEventSnapshot> reconcileOrphanStatus({
  required List<SavedEventSnapshot> saved,
  required Set<String> loadedEventRefs,
  required DateTime windowFrom,
  required DateTime windowTo,
  required bool Function(SavedEventSnapshot snapshot) belongsToThisSource,
}) {
  return saved.map((SavedEventSnapshot snapshot) {
    if (!belongsToThisSource(snapshot)) return snapshot;
    final bool startInWindow =
        !snapshot.start.isBefore(windowFrom) &&
        snapshot.start.isBefore(windowTo);
    if (!startInWindow) return snapshot;
    final bool present = loadedEventRefs.contains(snapshot.eventRef);
    if (present == !snapshot.isOrphaned) return snapshot;
    return snapshot.copyWith(isOrphaned: !present);
  }).toList();
}

/// Drops every snapshot whose reference point (end, or start when it has no
/// end) is more than [kSavedEventsRetention] in the past — the automatic
/// 365-day-after-end cleanup. Never touches an entry still inside the
/// retention window, however old [now] otherwise is.
List<SavedEventSnapshot> pruneExpiredSavedEvents(
  List<SavedEventSnapshot> saved, {
  required DateTime now,
}) {
  return saved.where((SavedEventSnapshot snapshot) {
    final DateTime reference = snapshot.end ?? snapshot.start;
    return now.difference(reference) < kSavedEventsRetention;
  }).toList();
}

/// The two deterministic groups the saved list shows.
class SavedEventsGroups {
  const SavedEventsGroups({required this.upcoming, required this.past});

  /// Running/upcoming entries, start ascending.
  final List<SavedEventSnapshot> upcoming;

  /// Past entries, start descending (most recently past first).
  final List<SavedEventSnapshot> past;
}

/// Splits [saved] into the upcoming/running and past groups at [now], each
/// deterministically ordered. A snapshot with no end is treated as past once
/// its start instant is behind [now]; "orphaned" is an orthogonal flag on
/// each snapshot and never removes it from either group.
SavedEventsGroups groupSavedEvents(
  List<SavedEventSnapshot> saved, {
  required DateTime now,
}) {
  bool isPast(SavedEventSnapshot snapshot) {
    final DateTime reference = snapshot.end ?? snapshot.start;
    return reference.isBefore(now);
  }

  final List<SavedEventSnapshot> upcoming =
      saved.where((SavedEventSnapshot s) => !isPast(s)).toList()..sort(
        (SavedEventSnapshot a, SavedEventSnapshot b) =>
            a.start.compareTo(b.start),
      );
  final List<SavedEventSnapshot> past = saved.where(isPast).toList()
    ..sort(
      (SavedEventSnapshot a, SavedEventSnapshot b) =>
          b.start.compareTo(a.start),
    );
  return SavedEventsGroups(upcoming: upcoming, past: past);
}
