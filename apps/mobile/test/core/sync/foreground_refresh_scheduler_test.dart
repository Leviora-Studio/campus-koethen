// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:campus_koethen/core/sync/foreground_refresh_scheduler.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_test/flutter_test.dart';

void main() {
  ForegroundRefreshScheduler build(
    FakeAsync async,
    List<DateTime> refreshes, {
    Duration interval = const Duration(minutes: 10),
    ForegroundResumeRefresh resumeRefresh = ForegroundResumeRefresh.whenDue,
  }) {
    final DateTime start = DateTime(2026, 8, 26, 12);
    DateTime clock() => start.add(async.elapsed);
    return ForegroundRefreshScheduler(
      interval: interval,
      resumeRefresh: resumeRefresh,
      clock: clock,
      onRefresh: () async => refreshes.add(clock()),
    );
  }

  test('refreshes on start and at the foreground interval', () {
    fakeAsync((FakeAsync async) {
      final List<DateTime> refreshes = <DateTime>[];
      final ForegroundRefreshScheduler scheduler = build(async, refreshes);

      scheduler.start();
      async.flushMicrotasks();
      async.elapse(const Duration(minutes: 9, seconds: 59));
      expect(refreshes, hasLength(1));

      async.elapse(const Duration(seconds: 1));
      expect(refreshes, hasLength(2));

      scheduler.dispose();
    });
  });

  test('whenDue resume preserves the ten-minute maximum', () {
    fakeAsync((FakeAsync async) {
      final List<DateTime> refreshes = <DateTime>[];
      final ForegroundRefreshScheduler scheduler = build(async, refreshes);

      scheduler.start();
      async.flushMicrotasks();
      scheduler.handleLifecycleState(AppLifecycleState.paused);
      async.elapse(const Duration(minutes: 4));
      scheduler.handleLifecycleState(AppLifecycleState.resumed);
      expect(
        refreshes,
        hasLength(1),
        reason: 'resume is still inside the gate',
      );

      async.elapse(const Duration(minutes: 6));
      expect(
        refreshes,
        hasLength(2),
        reason: 'the remaining six minutes are preserved after resume',
      );

      scheduler.dispose();
    });
  });

  test('whenDue resume refreshes immediately after the interval elapsed', () {
    fakeAsync((FakeAsync async) {
      final List<DateTime> refreshes = <DateTime>[];
      final ForegroundRefreshScheduler scheduler = build(async, refreshes);

      scheduler.start();
      async.flushMicrotasks();
      scheduler.handleLifecycleState(AppLifecycleState.paused);
      async.elapse(const Duration(hours: 2));
      scheduler.handleLifecycleState(AppLifecycleState.resumed);

      expect(refreshes, hasLength(2));
      scheduler.dispose();
    });
  });

  test('always resume refreshes even inside the regular interval', () {
    fakeAsync((FakeAsync async) {
      final List<DateTime> refreshes = <DateTime>[];
      final ForegroundRefreshScheduler scheduler = build(
        async,
        refreshes,
        interval: const Duration(minutes: 5),
        resumeRefresh: ForegroundResumeRefresh.always,
      );

      scheduler.start();
      async.flushMicrotasks();
      scheduler.handleLifecycleState(AppLifecycleState.paused);
      async.elapse(const Duration(seconds: 30));
      scheduler.handleLifecycleState(AppLifecycleState.resumed);

      expect(refreshes, hasLength(2));
      async.elapse(const Duration(minutes: 5));
      expect(refreshes, hasLength(3));
      scheduler.dispose();
    });
  });

  test('does not keep a timer alive outside the foreground', () {
    for (final AppLifecycleState state in <AppLifecycleState>[
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.detached,
    ]) {
      fakeAsync((FakeAsync async) {
        final List<DateTime> refreshes = <DateTime>[];
        final ForegroundRefreshScheduler scheduler = build(async, refreshes);

        scheduler.start();
        async.flushMicrotasks();
        scheduler.handleLifecycleState(state);

        expect(scheduler.hasActiveTimer, isFalse, reason: '$state');
        expect(async.nonPeriodicTimerCount + async.periodicTimerCount, 0);
        async.elapse(const Duration(days: 2));
        expect(refreshes, hasLength(1));
        scheduler.dispose();
      });
    }
  });
}
