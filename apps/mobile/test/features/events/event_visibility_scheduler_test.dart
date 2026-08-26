// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:campus_koethen/features/events/application/event_visibility_scheduler.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// Builds a scheduler whose clock follows the [FakeAsync] timeline.
  ///
  /// [nextBoundary] must behave like the real `nextVisibilityBoundary`
  /// contract it stands in for: every value it returns must be strictly
  /// after "now" at the moment it is read. A stub that returns a boundary
  /// equal to (or before) "now" — the one thing the real function
  /// deliberately guards against — would make the scheduler re-arm a
  /// zero-wait timer forever, which is a test-harness bug, not a production
  /// one; the tests below are built to never do that.
  EventVisibilityScheduler build(
    FakeAsync async,
    List<DateTime> recomputes, {
    required DateTime? Function() nextBoundary,
  }) {
    final DateTime start = DateTime(2026, 8, 20, 12);
    DateTime clock() => start.add(async.elapsed);
    return EventVisibilityScheduler(
      onRecompute: () => recomputes.add(clock()),
      nextBoundary: nextBoundary,
      clock: clock,
    );
  }

  test('recomputes once on start and arms a timer for the next boundary', () {
    fakeAsync((FakeAsync async) {
      final List<DateTime> recomputes = <DateTime>[];
      final DateTime boundary = DateTime(2026, 8, 20, 12, 5);
      final EventVisibilityScheduler scheduler = build(
        async,
        recomputes,
        nextBoundary: () => boundary,
      );

      scheduler.start();
      async.flushMicrotasks();

      expect(recomputes, hasLength(1));
      expect(scheduler.hasActiveTimer, isTrue);

      scheduler.dispose();
    });
  });

  test('fires exactly at the boundary, reschedules for the following one, and '
      'arms nothing once there is nothing left to hide — no polling', () {
    fakeAsync((FakeAsync async) {
      final List<DateTime> recomputes = <DateTime>[];
      // Each call consumes the next scheduled boundary, then — once the
      // list is exhausted, mirroring "nothing left to hide" — returns
      // null, so the scheduler stops arming timers on its own.
      final List<DateTime> schedule = <DateTime>[
        DateTime(2026, 8, 20, 12, 5),
        DateTime(2026, 8, 20, 13),
      ];
      int reads = 0;
      final EventVisibilityScheduler scheduler = build(
        async,
        recomputes,
        nextBoundary: () => reads < schedule.length ? schedule[reads++] : null,
      );

      scheduler.start();
      expect(recomputes, hasLength(1));

      async.elapse(const Duration(minutes: 4, seconds: 59));
      expect(
        recomputes,
        hasLength(1),
        reason: 'the boundary has not arrived yet',
      );
      expect(
        async.periodicTimerCount + async.nonPeriodicTimerCount,
        1,
        reason: 'exactly one timer is ever armed, never a poll loop',
      );

      async.elapse(const Duration(seconds: 1));
      expect(
        recomputes,
        hasLength(2),
        reason: 'fired exactly at the first boundary',
      );
      expect(
        scheduler.hasActiveTimer,
        isTrue,
        reason: 'rescheduled for the next one',
      );

      async.elapse(const Duration(minutes: 55));
      expect(
        recomputes,
        hasLength(3),
        reason: 'fired exactly at the second boundary',
      );
      expect(
        scheduler.hasActiveTimer,
        isFalse,
        reason: 'nothing left to hide, so nothing is re-armed',
      );

      scheduler.dispose();
    });
  });

  test('nothing scheduled to disappear leaves no timer armed', () {
    fakeAsync((FakeAsync async) {
      final List<DateTime> recomputes = <DateTime>[];
      final EventVisibilityScheduler scheduler = build(
        async,
        recomputes,
        nextBoundary: () => null,
      );

      scheduler.start();
      expect(recomputes, hasLength(1));
      expect(scheduler.hasActiveTimer, isFalse);
      expect(async.periodicTimerCount + async.nonPeriodicTimerCount, 0);

      scheduler.dispose();
    });
  });

  test('an app resume forces an immediate recompute and rearms the timer', () {
    fakeAsync((FakeAsync async) {
      final List<DateTime> recomputes = <DateTime>[];
      // Far enough out that it never actually fires during this test — the
      // point here is resume's own forced recompute, not a real boundary.
      final DateTime boundary = DateTime(2026, 8, 21, 12);
      final EventVisibilityScheduler scheduler = build(
        async,
        recomputes,
        nextBoundary: () => boundary,
      );

      scheduler.start();
      // A boundary can pass while the app sits backgrounded, with no timer
      // ever having fired to catch it — resume must re-evaluate immediately
      // rather than waiting for the stale armed timer.
      scheduler.handleLifecycleState(AppLifecycleState.paused);
      async.elapse(const Duration(hours: 3));

      scheduler.handleLifecycleState(AppLifecycleState.resumed);
      expect(recomputes, hasLength(2), reason: 'resume always recomputes');
      expect(scheduler.hasActiveTimer, isTrue);

      scheduler.dispose();
    });
  });

  test('a non-resume lifecycle change is inert', () {
    fakeAsync((FakeAsync async) {
      final List<DateTime> recomputes = <DateTime>[];
      final EventVisibilityScheduler scheduler = build(
        async,
        recomputes,
        nextBoundary: () => DateTime(2026, 8, 21, 12),
      );

      scheduler.start();
      scheduler.handleLifecycleState(AppLifecycleState.paused);
      expect(recomputes, hasLength(1));

      scheduler.dispose();
    });
  });

  test('recomputeNow forces an immediate recompute and reschedule', () {
    fakeAsync((FakeAsync async) {
      final List<DateTime> recomputes = <DateTime>[];
      final List<DateTime> schedule = <DateTime>[
        DateTime(2026, 8, 20, 12, 5),
        DateTime(2026, 8, 20, 12, 20),
      ];
      int reads = 0;
      final EventVisibilityScheduler scheduler = build(
        async,
        recomputes,
        nextBoundary: () => reads < schedule.length ? schedule[reads++] : null,
      );

      scheduler.start();
      expect(recomputes, hasLength(1));

      // A fresh load changed the underlying event list; the caller pushes a
      // recompute rather than waiting for the previously-armed timer.
      scheduler.recomputeNow();
      expect(recomputes, hasLength(2));

      async.elapse(const Duration(minutes: 20));
      expect(recomputes, hasLength(3));

      scheduler.dispose();
    });
  });

  test('fires nothing after dispose', () {
    fakeAsync((FakeAsync async) {
      final List<DateTime> recomputes = <DateTime>[];
      final EventVisibilityScheduler scheduler = build(
        async,
        recomputes,
        nextBoundary: () => DateTime(2026, 8, 20, 12, 5),
      );

      scheduler.start();
      scheduler.dispose();

      expect(scheduler.hasActiveTimer, isFalse);
      async.elapse(const Duration(hours: 6));
      expect(recomputes, hasLength(1));

      scheduler.handleLifecycleState(AppLifecycleState.resumed);
      expect(recomputes, hasLength(1));
    });
  });
}
