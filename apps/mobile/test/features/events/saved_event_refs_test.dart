// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:campus_koethen/features/events/application/saved_events_controller.dart';
import 'package:campus_koethen/features/events/data/saved_events_store.dart';
import 'package:campus_koethen/features/events/domain/unified_event.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

UnifiedEvent _event(String ref) => UnifiedEvent(
  eventRef: ref,
  kind: UnifiedEventKind.postEvent,
  title: 'Event $ref',
  start: DateTime.utc(2026, 8, 10, 18),
  channelSlug: 'campus-events',
  postSlug: ref.split(':').last,
);

ProviderContainer _container() {
  final ProviderContainer container = ProviderContainer(
    overrides: <Override>[
      savedEventsStoreProvider.overrideWithValue(MemorySavedEventsStore()),
      savedEventsClockProvider.overrideWithValue(
        () => DateTime.utc(2026, 8, 1),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

void main() {
  group('savedEventRefsProvider', () {
    test('answers membership from a set', () async {
      final ProviderContainer container = _container();
      await container.read(savedEventsControllerProvider.future);

      expect(container.read(savedEventRefsProvider), isEmpty);

      await container
          .read(savedEventsControllerProvider.notifier)
          .save(_event('post:a'));

      expect(container.read(savedEventRefsProvider), <String>{'post:a'});

      await container
          .read(savedEventsControllerProvider.notifier)
          .remove('post:a');

      expect(container.read(savedEventRefsProvider), isEmpty);
    });

    test(
      'saving one event never notifies a reader watching another one',
      () async {
        // This is what an event card selects on. Watching the list itself
        // woke every card whenever any event anywhere was saved.
        final ProviderContainer container = _container();
        await container.read(savedEventsControllerProvider.future);

        int aChanges = 0;
        int bChanges = 0;
        container.listen<bool>(
          savedEventRefsProvider.select(
            (Set<String> refs) => refs.contains('post:a'),
          ),
          (_, _) => aChanges++,
        );
        container.listen<bool>(
          savedEventRefsProvider.select(
            (Set<String> refs) => refs.contains('post:b'),
          ),
          (_, _) => bChanges++,
        );

        await container
            .read(savedEventsControllerProvider.notifier)
            .save(_event('post:a'));
        await container.pump();

        expect(aChanges, 1);
        expect(bChanges, 0);

        await container
            .read(savedEventsControllerProvider.notifier)
            .save(_event('post:b'));
        await container.pump();

        expect(aChanges, 1);
        expect(bChanges, 1);
      },
    );
  });
}
