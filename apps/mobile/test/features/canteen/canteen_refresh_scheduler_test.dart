// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'dart:async';

import 'package:campus_koethen/features/canteen/application/canteen_refresh_scheduler.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// Builds a scheduler whose clock follows the [FakeAsync] timeline.
  CanteenRefreshScheduler build(
    FakeAsync async,
    List<DateTime> refreshes, {
    Duration interval = const Duration(minutes: 5),
  }) {
    final DateTime start = DateTime(2026, 7, 22, 12);
    DateTime clock() => start.add(async.elapsed);
    return CanteenRefreshScheduler(
      interval: interval,
      clock: clock,
      onRefresh: () async => refreshes.add(clock()),
    );
  }

  test('refreshes once on app start', () {
    fakeAsync((FakeAsync async) {
      final List<DateTime> refreshes = <DateTime>[];
      final CanteenRefreshScheduler scheduler = build(async, refreshes);

      scheduler.start();
      async.flushMicrotasks();

      expect(refreshes, hasLength(1));
      scheduler.dispose();
    });
  });

  test('refreshes at most once every five minutes in the foreground', () {
    fakeAsync((FakeAsync async) {
      final List<DateTime> refreshes = <DateTime>[];
      final CanteenRefreshScheduler scheduler = build(async, refreshes);

      scheduler.start();
      async.elapse(const Duration(minutes: 4, seconds: 59));
      expect(refreshes, hasLength(1), reason: 'the interval has not elapsed');

      async.elapse(const Duration(seconds: 1));
      expect(refreshes, hasLength(2));

      async.elapse(const Duration(minutes: 5));
      expect(refreshes, hasLength(3));

      async.elapse(const Duration(minutes: 12));
      expect(
        refreshes,
        hasLength(5),
        reason: '12 minutes contain two more five minute ticks',
      );

      scheduler.dispose();
    });
  });

  test('refreshes on resume and re-arms the timer', () {
    fakeAsync((FakeAsync async) {
      final List<DateTime> refreshes = <DateTime>[];
      final CanteenRefreshScheduler scheduler = build(async, refreshes);

      scheduler.start();
      scheduler.handleLifecycleState(AppLifecycleState.paused);
      async.elapse(const Duration(hours: 2));
      expect(refreshes, hasLength(1));

      scheduler.handleLifecycleState(AppLifecycleState.resumed);
      expect(refreshes, hasLength(2), reason: 'resume always refreshes');
      expect(scheduler.hasActiveTimer, isTrue);

      async.elapse(const Duration(minutes: 5));
      expect(refreshes, hasLength(3));

      scheduler.dispose();
    });
  });

  test('cancels the timer when the app leaves the foreground', () {
    for (final AppLifecycleState state in <AppLifecycleState>[
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.detached,
    ]) {
      fakeAsync((FakeAsync async) {
        final List<DateTime> refreshes = <DateTime>[];
        final CanteenRefreshScheduler scheduler = build(async, refreshes);

        scheduler.start();
        expect(scheduler.hasActiveTimer, isTrue);

        scheduler.handleLifecycleState(state);

        expect(
          scheduler.hasActiveTimer,
          isFalse,
          reason: 'no timer may survive $state',
        );
        expect(
          async.periodicTimerCount + async.nonPeriodicTimerCount,
          0,
          reason: 'no pending timer at all after $state',
        );

        async.elapse(const Duration(hours: 6));
        expect(
          refreshes,
          hasLength(1),
          reason:
              'only the start refresh happened; no timer fired after $state',
        );

        scheduler.dispose();
      });
    }
  });

  test('fires nothing after dispose', () {
    fakeAsync((FakeAsync async) {
      final List<DateTime> refreshes = <DateTime>[];
      final CanteenRefreshScheduler scheduler = build(async, refreshes);

      scheduler.start();
      scheduler.dispose();

      expect(scheduler.hasActiveTimer, isFalse);
      expect(async.periodicTimerCount + async.nonPeriodicTimerCount, 0);

      async.elapse(const Duration(hours: 6));
      expect(refreshes, hasLength(1));

      // A late lifecycle callback must stay inert too.
      scheduler.handleLifecycleState(AppLifecycleState.resumed);
      async.elapse(const Duration(hours: 1));
      expect(refreshes, hasLength(1));
      expect(scheduler.hasActiveTimer, isFalse);
    });
  });

  test('does not overlap slow refreshes', () {
    fakeAsync((FakeAsync async) {
      final Completer<void> firstRefresh = Completer<void>();
      int refreshCount = 0;
      final CanteenRefreshScheduler scheduler = CanteenRefreshScheduler(
        interval: const Duration(minutes: 5),
        clock: () => DateTime(2026, 7, 22, 12).add(async.elapsed),
        onRefresh: () {
          refreshCount += 1;
          return refreshCount == 1 ? firstRefresh.future : Future<void>.value();
        },
      );

      scheduler.start();
      async.flushMicrotasks();
      expect(refreshCount, 1);

      async.elapse(const Duration(minutes: 5));
      async.flushMicrotasks();
      expect(
        refreshCount,
        1,
        reason: 'a second network refresh must not overlap the first one',
      );

      firstRefresh.complete();
      async.flushMicrotasks();
      async.elapse(const Duration(minutes: 5));
      async.flushMicrotasks();
      expect(refreshCount, 2);

      scheduler.dispose();
    });
  });
}
