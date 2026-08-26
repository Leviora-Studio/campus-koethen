// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'dart:async';

import 'package:flutter/widgets.dart' show AppLifecycleState;

/// Drives the event overview's time-boundary re-evaluation.
///
/// Per contract: time boundaries are re-evaluated on rebuild and on app
/// resume, and **exactly one** [Timer] is armed for the next relevant
/// boundary and rescheduled after it fires — never polling.
///
/// Mirrors `CanteenRefreshScheduler`'s shape (plain Dart, injectable clock,
/// `handleLifecycleState`), so it is testable the same way with `fake_async`
/// and driven by the same widget-level lifecycle hook.
class EventVisibilityScheduler {
  EventVisibilityScheduler({
    required this.onRecompute,
    required this.nextBoundary,
    DateTime Function()? clock,
  }) : _clock = clock ?? DateTime.now;

  /// Called every time visibility must be re-evaluated: on start, on an app
  /// resume, and whenever the armed timer fires.
  final void Function() onRecompute;

  /// Returns the next boundary strictly after "now" that should trigger a
  /// recompute, or `null` when nothing is currently scheduled to change.
  final DateTime? Function() nextBoundary;

  final DateTime Function() _clock;

  Timer? _timer;
  bool _disposed = false;

  /// Whether a boundary timer is currently armed. Used by tests.
  bool get hasActiveTimer => _timer != null;

  /// First recompute, then arms the timer for the next boundary.
  void start() {
    if (_disposed) return;
    onRecompute();
    _reschedule();
  }

  /// Feeds the platform lifecycle into the policy: a resume forces an
  /// immediate recompute (a boundary can have passed while backgrounded, with
  /// no timer having fired) and rearms the timer.
  void handleLifecycleState(AppLifecycleState state) {
    if (_disposed) return;
    if (state == AppLifecycleState.resumed) {
      onRecompute();
      _reschedule();
    }
  }

  /// Forces an immediate recompute and reschedule — used when the underlying
  /// event list itself changes (a fresh load), not only when time passes.
  void recomputeNow() {
    if (_disposed) return;
    onRecompute();
    _reschedule();
  }

  /// Cancels the timer. After this the scheduler is inert.
  void dispose() {
    _disposed = true;
    _cancel();
  }

  void _reschedule() {
    _cancel();
    final DateTime? boundary = nextBoundary();
    if (boundary == null) return;
    final Duration wait = boundary.difference(_clock());
    _timer = Timer(wait.isNegative ? Duration.zero : wait, _onFire);
  }

  void _onFire() {
    if (_disposed) return;
    onRecompute();
    _reschedule();
  }

  void _cancel() {
    _timer?.cancel();
    _timer = null;
  }
}
