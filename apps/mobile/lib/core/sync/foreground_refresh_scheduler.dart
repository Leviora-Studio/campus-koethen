// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'dart:async';

import 'package:flutter/widgets.dart' show AppLifecycleState;

/// Determines whether returning to the foreground refreshes immediately or
/// only after the regular interval has elapsed.
enum ForegroundResumeRefresh { always, whenDue }

/// Runs one refresh loop only while the app is in the foreground.
///
/// The first refresh happens on [start]. Leaving the foreground cancels the
/// timer completely. On resume, [resumeRefresh] decides whether to refresh
/// immediately or preserve the minimum [interval] between two attempts.
class ForegroundRefreshScheduler {
  ForegroundRefreshScheduler({
    required this.onRefresh,
    required this.interval,
    this.resumeRefresh = ForegroundResumeRefresh.whenDue,
    DateTime Function()? clock,
  }) : assert(interval > Duration.zero),
       _clock = clock ?? DateTime.now;

  final Future<void> Function() onRefresh;
  final Duration interval;
  final ForegroundResumeRefresh resumeRefresh;
  final DateTime Function() _clock;

  Timer? _timer;
  DateTime? _lastRefreshAt;
  bool _refreshInFlight = false;
  bool _disposed = false;

  bool get hasActiveTimer => _timer != null;
  DateTime? get lastRefreshAt => _lastRefreshAt;

  void start() {
    if (_disposed) return;
    _refreshNow();
    _armForNextDueTime();
  }

  void handleLifecycleState(AppLifecycleState state) {
    if (_disposed) return;
    switch (state) {
      case AppLifecycleState.resumed:
        if (resumeRefresh == ForegroundResumeRefresh.always) {
          _refreshNow();
        } else {
          _refreshIfDue();
        }
        _armForNextDueTime();
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
      case AppLifecycleState.detached:
        _cancelTimer();
    }
  }

  void dispose() {
    _disposed = true;
    _cancelTimer();
  }

  void _refreshIfDue() {
    final DateTime? last = _lastRefreshAt;
    if (last != null && _clock().difference(last) < interval) return;
    _refreshNow();
  }

  void _refreshNow() {
    if (_disposed || _refreshInFlight) return;
    _lastRefreshAt = _clock();
    _refreshInFlight = true;
    unawaited(
      Future<void>.sync(onRefresh)
          // Automatic refresh errors are represented by the providers. They
          // must not escape as uncaught asynchronous framework errors.
          .onError((Object _, StackTrace _) {})
          .whenComplete(() => _refreshInFlight = false),
    );
  }

  void _armForNextDueTime() {
    _cancelTimer();
    if (_disposed) return;

    final DateTime? last = _lastRefreshAt;
    final Duration elapsed = last == null
        ? interval
        : _clock().difference(last);
    final Duration delay = elapsed >= interval ? interval : interval - elapsed;
    _timer = Timer(delay, () {
      if (_refreshInFlight) {
        _armForNextDueTime();
        return;
      }
      _refreshIfDue();
      _armForNextDueTime();
    });
  }

  void _cancelTimer() {
    _timer?.cancel();
    _timer = null;
  }
}
