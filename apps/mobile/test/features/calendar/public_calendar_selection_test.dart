// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:campus_koethen/core/prefs/key_value_store.dart';
import 'package:campus_koethen/core/prefs/settings_controller.dart';
import 'package:campus_koethen/features/calendar/application/public_calendar_selection.dart';
import 'package:campus_koethen/features/calendar/domain/public_calendar.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

PublicCalendar cal(String slug, {bool defaultSubscribed = false}) =>
    PublicCalendar(
      id: 'id-$slug',
      slug: slug,
      name: 'Kalender $slug',
      colorHex: '#5B3FD0',
      sortOrder: 0,
      defaultSubscribed: defaultSubscribed,
      googleOpenUrl: 'https://calendar.google.com/calendar/render?cid=x',
    );

void main() {
  group('PublicCalendarSelectionRules.reconcile', () {
    test('activates a new defaultSubscribed calendar exactly once', () {
      final s0 = PublicCalendarSelectionState.empty;
      final s1 = PublicCalendarSelectionRules.reconcile(s0, [
        cal('a', defaultSubscribed: true),
      ]);
      expect(s1.isSelected('a'), isTrue);

      // The user turns it off; a later reconcile must NOT re-activate it.
      final s2 = s1.copyWith(selectedSlugs: <String>{});
      final s3 = PublicCalendarSelectionRules.reconcile(s2, [
        cal('a', defaultSubscribed: true),
      ]);
      expect(s3.isSelected('a'), isFalse);
    });

    test('a non-default calendar starts deactivated', () {
      final s = PublicCalendarSelectionRules.reconcile(
        PublicCalendarSelectionState.empty,
        [cal('b')],
      );
      expect(s.isSelected('b'), isFalse);
      expect(s.seenSlugs, contains('b'));
    });

    test('an empty catalogue never wipes the selection', () {
      final s0 = PublicCalendarSelectionState(
        seenSlugs: {'a'},
        selectedSlugs: {'a'},
      );
      final s1 = PublicCalendarSelectionRules.reconcile(
        s0,
        const <PublicCalendar>[],
      );
      expect(s1.selectedSlugs, contains('a'));
    });

    test('a vanished slug is pruned from the selection but kept as seen', () {
      final s0 = PublicCalendarSelectionState(
        seenSlugs: {'a', 'b'},
        selectedSlugs: {'a', 'b'},
      );
      final s1 = PublicCalendarSelectionRules.reconcile(s0, [cal('a')]);
      expect(s1.selectedSlugs, <String>{'a'});
      expect(s1.seenSlugs, containsAll(<String>['a', 'b']));
    });

    test(
      'effectiveSelection returns only catalogued, selected slugs, sorted',
      () {
        final selection = PublicCalendarSelectionRules.effectiveSelection(
          available: [cal('b'), cal('a')],
          selected: {'a', 'b', 'ghost'},
        );
        expect(selection, <String>['a', 'b']);
      },
    );
  });

  group('PublicCalendarSelectionController (storage round-trip)', () {
    ProviderContainer containerWith(KeyValueStore store) {
      final c = ProviderContainer(
        overrides: <Override>[keyValueStoreProvider.overrideWithValue(store)],
      );
      addTearDown(c.dispose);
      return c;
    }

    test('persists a selection and reloads it', () async {
      final store = InMemoryKeyValueStore();
      final c1 = containerWith(store);
      await c1
          .read(publicCalendarSelectionProvider.notifier)
          .setSelected('a', selected: true);
      expect(c1.read(publicCalendarSelectionProvider).isSelected('a'), isTrue);

      // A fresh container backed by the same store restores the selection.
      final c2 = containerWith(store);
      expect(c2.read(publicCalendarSelectionProvider).isSelected('a'), isTrue);
    });

    test('reconcile persists defaults on first appearance only', () async {
      final store = InMemoryKeyValueStore();
      final c = containerWith(store);
      await c.read(publicCalendarSelectionProvider.notifier).reconcile([
        cal('a', defaultSubscribed: true),
        cal('b'),
      ]);
      final state = c.read(publicCalendarSelectionProvider);
      expect(state.isSelected('a'), isTrue);
      expect(state.isSelected('b'), isFalse);
      expect(state.seenSlugs, containsAll(<String>['a', 'b']));
    });
  });
}
