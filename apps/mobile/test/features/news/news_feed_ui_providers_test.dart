// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:campus_koethen/features/news/application/news_feed_ui_providers.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('the expansion state', () {
    test('is empty until an article is opened', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(newsExpansionProvider), isEmpty);
    });

    test('is kept per slug, so one article does not open another', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(newsExpansionProvider.notifier).toggle('a');

      expect(container.read(newsExpansionProvider), <String>{'a'});
    });

    test('toggling twice closes the article again', () {
      final ProviderContainer container = ProviderContainer();
      addTearDown(container.dispose);
      final NewsExpansionController controller = container.read(
        newsExpansionProvider.notifier,
      );

      controller.toggle('a');
      controller.toggle('b');
      controller.toggle('a');

      expect(container.read(newsExpansionProvider), <String>{'b'});
    });
  });

  group('the feed clock', () {
    test('moves on while the feed is open', () {
      // "vor 3 min" has to stay honest while somebody is reading.
      fakeAsync((FakeAsync async) {
        final ProviderContainer container = ProviderContainer();
        final DateTime start = container.read(newsClockProvider);

        async.elapse(const Duration(minutes: 2));

        expect(
          container.read(newsClockProvider).isAfter(start),
          isTrue,
          reason: 'the clock ticked',
        );
        container.dispose();
      });
    });

    test('stops when nothing watches it any more', () {
      // One timer for the whole list, and none once the feed is gone.
      fakeAsync((FakeAsync async) {
        final ProviderContainer container = ProviderContainer();
        final ProviderSubscription<DateTime> subscription = container.listen(
          newsClockProvider,
          (_, _) {},
        );

        subscription.close();
        async.flushMicrotasks();
        async.elapse(const Duration(minutes: 5));

        expect(async.pendingTimers, isEmpty);
        container.dispose();
      });
    });
  });
}
