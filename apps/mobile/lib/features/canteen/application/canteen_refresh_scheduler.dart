// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:flutter/widgets.dart' show AppLifecycleState;

import '../../../core/sync/foreground_refresh_scheduler.dart';

/// Implements the canteen refresh policy.
///
/// * refresh on app start,
/// * refresh on app resume,
/// * additionally at most once every [interval] while in the foreground.
///
/// **No timer ever runs in the background.** Leaving the foreground cancels the
/// scheduled timer; returning schedules a fresh one. [dispose] cancels it too.
/// This is asserted by `test/features/canteen/canteen_refresh_scheduler_test.dart`.
class CanteenRefreshScheduler {
  CanteenRefreshScheduler({
    required Future<void> Function() onRefresh,
    Duration interval = const Duration(minutes: 5),
    DateTime Function()? clock,
  }) : _scheduler = ForegroundRefreshScheduler(
         onRefresh: onRefresh,
         interval: interval,
         resumeRefresh: ForegroundResumeRefresh.always,
         clock: clock,
       );

  final ForegroundRefreshScheduler _scheduler;

  /// Whether a timer is currently armed. Used by tests.
  bool get hasActiveTimer => _scheduler.hasActiveTimer;

  /// Time of the last refresh this scheduler triggered.
  DateTime? get lastRefreshAt => _scheduler.lastRefreshAt;

  /// Called once when the screen is first shown: refresh now, then arm the
  /// next timer.
  void start() => _scheduler.start();

  /// Feeds the platform lifecycle into the policy.
  void handleLifecycleState(AppLifecycleState state) =>
      _scheduler.handleLifecycleState(state);

  /// Cancels the timer. After this the scheduler is inert.
  void dispose() => _scheduler.dispose();
}
