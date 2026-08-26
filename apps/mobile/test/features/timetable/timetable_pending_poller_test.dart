// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:campus_koethen/features/timetable/application/timetable_pending_poller.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_test/flutter_test.dart';

void main() {
  TimetablePendingPoller build(List<int> retries, {int maxAttempts = 4}) {
    return TimetablePendingPoller(
      initialDelay: const Duration(seconds: 20),
      maxDelay: const Duration(minutes: 5),
      maxAttempts: maxAttempts,
      onRetry: () async => retries.add(retries.length + 1),
    );
  }

  test('does nothing while the data state is not pending', () {
    fakeAsync((FakeAsync async) {
      final List<int> retries = <int>[];
      final TimetablePendingPoller poller = build(retries);

      poller.update(isPending: false);
      async.elapse(const Duration(hours: 3));

      expect(retries, isEmpty);
      expect(poller.hasActiveTimer, isFalse);
      poller.dispose();
    });
  });

  test('re-checks with an exponential backoff', () {
    fakeAsync((FakeAsync async) {
      final List<int> retries = <int>[];
      final TimetablePendingPoller poller = build(retries);

      poller.update(isPending: true);
      expect(retries, isEmpty, reason: 'the first check is the screen load');

      async.elapse(const Duration(seconds: 19));
      expect(retries, isEmpty);
      async.elapse(const Duration(seconds: 1));
      expect(retries, hasLength(1), reason: 'first retry after 20s');

      // Still pending: the screen reports the state again.
      poller.update(isPending: true);
      async.elapse(const Duration(seconds: 39));
      expect(retries, hasLength(1));
      async.elapse(const Duration(seconds: 1));
      expect(retries, hasLength(2), reason: 'second retry after 40s');

      poller.update(isPending: true);
      async.elapse(const Duration(seconds: 80));
      expect(retries, hasLength(3), reason: 'third retry after 80s');

      poller.dispose();
    });
  });

  test('never exceeds the hard attempt limit', () {
    fakeAsync((FakeAsync async) {
      final List<int> retries = <int>[];
      final TimetablePendingPoller poller = build(retries, maxAttempts: 3);

      for (int i = 0; i < 20; i++) {
        poller.update(isPending: true);
        async.elapse(const Duration(hours: 1));
      }

      expect(retries, hasLength(3), reason: 'a hard upper bound, no polling');
      expect(poller.isExhausted, isTrue);
      expect(poller.hasActiveTimer, isFalse);
      expect(async.periodicTimerCount + async.nonPeriodicTimerCount, 0);
      poller.dispose();
    });
  });

  test('caps the delay at maxDelay', () {
    fakeAsync((FakeAsync async) {
      final List<int> retries = <int>[];
      final TimetablePendingPoller poller = build(retries, maxAttempts: 10);

      // 20s, 40s, 80s, 160s, then the cap of 300s applies.
      for (final Duration delay in <Duration>[
        Duration(seconds: 20),
        Duration(seconds: 40),
        Duration(seconds: 80),
        Duration(seconds: 160),
        Duration(seconds: 300),
        Duration(seconds: 300),
      ]) {
        poller.update(isPending: true);
        async.elapse(delay - const Duration(seconds: 1));
        final int before = retries.length;
        async.elapse(const Duration(seconds: 1));
        expect(
          retries.length,
          before + 1,
          reason: 'a retry was due exactly after $delay',
        );
      }

      poller.dispose();
    });
  });

  test('a repeated report does not arm a second timer', () {
    fakeAsync((FakeAsync async) {
      final List<int> retries = <int>[];
      final TimetablePendingPoller poller = build(retries);

      for (int i = 0; i < 10; i++) {
        poller.update(isPending: true);
      }
      expect(async.nonPeriodicTimerCount, 1, reason: 'exactly one timer');

      async.elapse(const Duration(seconds: 20));
      expect(retries, hasLength(1));
      poller.dispose();
    });
  });

  test('resets once the data arrived', () {
    fakeAsync((FakeAsync async) {
      final List<int> retries = <int>[];
      final TimetablePendingPoller poller = build(retries);

      poller.update(isPending: true);
      async.elapse(const Duration(seconds: 20));
      expect(retries, hasLength(1));

      poller.update(isPending: false);
      expect(poller.hasActiveTimer, isFalse);
      expect(poller.attempts, 0, reason: 'a later pending starts over');

      poller.update(isPending: true);
      async.elapse(const Duration(seconds: 20));
      expect(retries, hasLength(2), reason: 'back to the initial delay');

      poller.dispose();
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
        final List<int> retries = <int>[];
        final TimetablePendingPoller poller = build(retries);

        poller.update(isPending: true);
        expect(poller.hasActiveTimer, isTrue);

        poller.handleLifecycleState(state);

        expect(
          poller.hasActiveTimer,
          isFalse,
          reason: 'no timer survives $state',
        );
        expect(async.periodicTimerCount + async.nonPeriodicTimerCount, 0);

        async.elapse(const Duration(hours: 6));
        expect(retries, isEmpty, reason: 'nothing fired in the background');

        poller.handleLifecycleState(AppLifecycleState.resumed);
        expect(
          poller.hasActiveTimer,
          isTrue,
          reason: 'coming back re-arms the pending check',
        );

        poller.dispose();
      });
    }
  });

  test('fires nothing after dispose', () {
    fakeAsync((FakeAsync async) {
      final List<int> retries = <int>[];
      final TimetablePendingPoller poller = build(retries);

      poller.update(isPending: true);
      poller.dispose();

      expect(poller.hasActiveTimer, isFalse);
      expect(async.periodicTimerCount + async.nonPeriodicTimerCount, 0);

      async.elapse(const Duration(hours: 6));
      expect(retries, isEmpty);

      // Late callbacks must stay inert.
      poller.update(isPending: true);
      poller.handleLifecycleState(AppLifecycleState.resumed);
      async.elapse(const Duration(hours: 1));

      expect(retries, isEmpty);
      expect(poller.hasActiveTimer, isFalse);
    });
  });
}
