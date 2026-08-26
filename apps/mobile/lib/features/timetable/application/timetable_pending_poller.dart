// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'dart:async';

import 'package:flutter/widgets.dart' show AppLifecycleState;

/// Re-checks the Campus API while a timetable range is still being prepared.
///
/// `dataState: pending` means the backend has not finished a successful run for
/// the requested range yet. Instead of leaving the user on a dead screen the
/// app asks again — but **deliberately not aggressively**:
///
/// * one-shot timers only, never a periodic poll,
/// * exponential backoff ([initialDelay], doubled each time, capped at
///   [maxDelay]),
/// * a hard upper bound of [maxAttempts] retries per range; afterwards the user
///   has to refresh manually,
/// * **no timer ever runs in the background** — leaving the foreground cancels
///   it, returning re-arms it, [dispose] makes the poller inert.
///
/// This is asserted by `test/features/timetable/timetable_pending_poller_test.dart`.
class TimetablePendingPoller {
  TimetablePendingPoller({
    required this.onRetry,
    this.initialDelay = const Duration(seconds: 20),
    this.maxDelay = const Duration(minutes: 5),
    this.maxAttempts = 4,
  });

  /// Triggered by every re-check this policy decides on.
  final Future<void> Function() onRetry;

  /// Delay before the first re-check.
  final Duration initialDelay;

  /// Upper bound for a single delay.
  final Duration maxDelay;

  /// Hard upper bound of re-checks per pending range.
  final int maxAttempts;

  Timer? _timer;
  int _attempts = 0;
  bool _isPending = false;
  bool _disposed = false;

  /// Whether a re-check is currently armed. Used by tests.
  bool get hasActiveTimer => _timer != null;

  /// Number of re-checks already triggered for the current pending range.
  int get attempts => _attempts;

  /// Whether the hard upper bound has been reached.
  bool get isExhausted => _attempts >= maxAttempts;

  /// Reports the current data state. Safe to call on every rebuild: an already
  /// armed timer is never replaced, so rebuilds cannot shorten the backoff.
  void update({required bool isPending}) {
    if (_disposed) return;
    if (!isPending) {
      _isPending = false;
      _attempts = 0;
      _cancel();
      return;
    }
    _isPending = true;
    _arm();
  }

  /// Feeds the platform lifecycle into the policy.
  void handleLifecycleState(AppLifecycleState state) {
    if (_disposed) return;
    switch (state) {
      case AppLifecycleState.resumed:
        if (_isPending) _arm();
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _cancel();
    }
  }

  /// Cancels everything. After this the poller is inert.
  void dispose() {
    _disposed = true;
    _isPending = false;
    _cancel();
  }

  void _arm() {
    if (_timer != null || isExhausted) return;
    _timer = Timer(_nextDelay(), _fire);
  }

  void _cancel() {
    _timer?.cancel();
    _timer = null;
  }

  void _fire() {
    _timer = null;
    if (_disposed || !_isPending) return;
    _attempts++;
    unawaited(onRetry());
  }

  /// `initialDelay * 2^attempts`, capped at [maxDelay].
  Duration _nextDelay() {
    final int factor = 1 << _attempts;
    final int micros = initialDelay.inMicroseconds * factor;
    return micros >= maxDelay.inMicroseconds || micros <= 0
        ? maxDelay
        : Duration(microseconds: micros);
  }
}
