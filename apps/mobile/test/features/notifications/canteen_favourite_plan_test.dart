// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:campus_koethen/core/network/api_meta.dart';
import 'package:campus_koethen/core/network/loaded.dart';
import 'package:campus_koethen/core/prefs/key_value_store.dart';
import 'package:campus_koethen/core/prefs/settings_controller.dart';
import 'package:campus_koethen/core/time/clock.dart';
import 'package:campus_koethen/features/canteen/application/canteen_filter_controller.dart';
import 'package:campus_koethen/features/canteen/application/canteen_providers.dart';
import 'package:campus_koethen/features/canteen/data/canteen_models.dart';
import 'package:campus_koethen/features/notifications/application/notification_providers.dart';
import 'package:campus_koethen/features/notifications/application/notification_settings_controller.dart';
import 'package:campus_koethen/features/notifications/data/device_time_zone.dart';
import 'package:campus_koethen/features/notifications/domain/notification_category.dart';
import 'package:campus_koethen/features/notifications/domain/notification_plan.dart';
import 'package:campus_koethen/features/notifications/domain/planned_notification.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_notification_gateway.dart';

/// The provider side of N3: that a change to a favourite, to the menu, to the
/// canteen or to the category switch really does arrive as a **new whole
/// plan**, without a trigger list and without a second code path for
/// "cancel". Every one of these is a rule from the issue's acceptance
/// criteria, and none of them is visible in the pure builder alone.

class _FixedClock implements Clock {
  const _FixedClock(this._now);
  final DateTime _now;
  @override
  DateTime now() => _now;
}

final DateTime today = DateTime(2026, 9, 3);
final DateTime tomorrow = DateTime(2026, 9, 4);

/// 07:30 in Europe/Berlin — the zone [containerFor] pins, written as the
/// instant it actually is.
///
/// A wall-clock literal would be read in the **host's** zone, while the plan
/// converts it into the pinned one (`tz.TZDateTime.from`). The two only agree
/// on a machine that happens to run in Berlin, so the same test said different
/// things locally and in CI, which pins `TZ=Europe/Berlin` on purpose. Whether
/// the 08:00 overview is still ahead of "now" turned on exactly that.
final DateTime morning = DateTime.utc(2026, 9, 3, 5, 30);

Meal meal(String name) => Meal(
  id: 'id-$name',
  name: name,
  prices: const <MealPrice>[
    MealPrice(
      group: 'student',
      label: 'Studierende',
      amount: '2.80',
      currency: 'EUR',
    ),
  ],
);

Loaded<CanteenMenu> menuOf(String slug, Map<DateTime, List<Meal>> days) =>
    Loaded<CanteenMenu>(
      value: CanteenMenu(
        canteenSlug: slug,
        displayName: 'Mensa $slug',
        days: <MenuDay>[
          for (final MapEntry<DateTime, List<Meal>> e in days.entries)
            MenuDay(date: e.key, meals: e.value),
        ],
      ),
      meta: const ApiMeta(),
    );

ProviderContainer containerFor({
  required String slug,
  required Map<String, Map<DateTime, List<Meal>>> menus,
  KeyValueStore? store,
}) {
  final ProviderContainer container = ProviderContainer(
    overrides: <Override>[
      keyValueStoreProvider.overrideWithValue(store ?? InMemoryKeyValueStore()),
      notificationGatewayProvider.overrideWithValue(FakeNotificationGateway()),
      timeZoneResolverProvider.overrideWithValue(
        FixedTimeZoneResolver('Europe/Berlin'),
      ),
      notificationClockProvider.overrideWithValue(_FixedClock(morning)),
      selectedCanteenSlugProvider.overrideWithValue(slug),
      canteenMenuProvider.overrideWith(
        (Ref ref, String requested) async => menuOf(
          requested,
          menus[requested] ?? const <DateTime, List<Meal>>{},
        ),
      ),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

/// Resolves the two asynchronous inputs of the plan — the zone and the
/// permission — so the plan is a real answer rather than the empty placeholder
/// it shows while they load.
Future<void> settle(ProviderContainer container) async {
  await container.read(notificationLocationProvider.future);
  await container.read(notificationPermissionProvider.future);
  await container.read(
    canteenMenuProvider(container.read(selectedCanteenSlugProvider)!).future,
  );
}

Future<List<String>> canteenFavouriteKeysOf(ProviderContainer container) async {
  await settle(container);
  return container
      .read(notificationPlanProvider)
      .notifications
      .where(
        (PlannedNotification notification) =>
            notification.category == NotificationCategory.canteenFavourite,
      )
      .map((PlannedNotification n) => n.key)
      .toList(growable: false);
}

void main() {
  test(
    'a favourite in the preferred canteen is planned once per day',
    () async {
      final ProviderContainer container = containerFor(
        slug: 'fasanerieallee',
        menus: <String, Map<DateTime, List<Meal>>>{
          'fasanerieallee': <DateTime, List<Meal>>{
            today: <Meal>[meal('Käsespätzle')],
            tomorrow: <Meal>[meal('Käsespätzle')],
          },
        },
      );
      await settle(container);
      await container
          .read(notificationSettingsProvider.notifier)
          .setOptedIn(true);
      await container
          .read(canteenFilterProvider.notifier)
          .toggleFavourite(meal('Käsespätzle'));

      expect(await canteenFavouriteKeysOf(container), <String>[
        // 11:00 today is still ahead of the 07:30 the clock is fixed at.
        'n3:fasanerieallee:2026-09-03',
        'n3:fasanerieallee:2026-09-04',
      ]);
    },
  );

  test(
    'removing the favourite empties the plan — no cancel path of its own',
    () async {
      final ProviderContainer container = containerFor(
        slug: 'fasanerieallee',
        menus: <String, Map<DateTime, List<Meal>>>{
          'fasanerieallee': <DateTime, List<Meal>>{
            today: <Meal>[meal('Käsespätzle')],
          },
        },
      );
      await settle(container);
      await container
          .read(notificationSettingsProvider.notifier)
          .setOptedIn(true);
      final CanteenFilterController filter = container.read(
        canteenFilterProvider.notifier,
      );
      await filter.toggleFavourite(meal('Käsespätzle'));
      expect(await canteenFavouriteKeysOf(container), hasLength(1));

      await filter.removeFavouriteNamed('Käsespätzle');

      expect(await canteenFavouriteKeysOf(container), isEmpty);
    },
  );

  test('switching the category off cancels the hints, nothing else', () async {
    final ProviderContainer container = containerFor(
      slug: 'fasanerieallee',
      menus: <String, Map<DateTime, List<Meal>>>{
        'fasanerieallee': <DateTime, List<Meal>>{
          today: <Meal>[meal('Käsespätzle')],
        },
      },
    );
    await settle(container);
    await container
        .read(notificationSettingsProvider.notifier)
        .setOptedIn(true);
    await container
        .read(canteenFilterProvider.notifier)
        .toggleFavourite(meal('Käsespätzle'));
    expect(await canteenFavouriteKeysOf(container), hasLength(1));

    await container
        .read(notificationSettingsProvider.notifier)
        .setCategoryEnabled(NotificationCategory.canteenFavourite, false);

    await settle(container);
    final NotificationPlan plan = container.read(notificationPlanProvider);

    // The hints are gone, and they are gone for the stated reason.
    expect(
      plan.notifications.where(
        (PlannedNotification n) =>
            n.category == NotificationCategory.canteenFavourite,
      ),
      isEmpty,
    );
    expect(
      plan.diagnostics.droppedFor(NotificationDropReason.categoryDisabled),
      1,
    );

    // "Nothing else": switching one category off is not a way to cancel the
    // others. The 08:00 overview of the same day is still planned — asserting
    // an empty plan here said the opposite of what this test is named after,
    // and only ever held because the host's zone put 08:00 in the past.
    expect(
      plan.notifications.map((PlannedNotification n) => n.category),
      contains(NotificationCategory.dailySummary),
    );
  });

  test(
    'a menu that no longer offers the dish replaces the old planning',
    () async {
      final Map<String, Map<DateTime, List<Meal>>> menus =
          <String, Map<DateTime, List<Meal>>>{
            'fasanerieallee': <DateTime, List<Meal>>{
              today: <Meal>[meal('Käsespätzle')],
            },
          };
      final ProviderContainer container = containerFor(
        slug: 'fasanerieallee',
        menus: menus,
      );
      await settle(container);
      await container
          .read(notificationSettingsProvider.notifier)
          .setOptedIn(true);
      await container
          .read(canteenFilterProvider.notifier)
          .toggleFavourite(meal('Käsespätzle'));
      expect(await canteenFavouriteKeysOf(container), hasLength(1));

      // The next successful fetch: the dish is gone from the day.
      menus['fasanerieallee'] = <DateTime, List<Meal>>{
        today: <Meal>[meal('Linsen')],
      };
      container.invalidate(canteenMenuProvider);

      expect(await canteenFavouriteKeysOf(container), isEmpty);
    },
  );

  test('a hint is only ever about the canteen the reader follows', () async {
    final ProviderContainer container = containerFor(
      slug: 'am-tierpark',
      menus: <String, Map<DateTime, List<Meal>>>{
        'fasanerieallee': <DateTime, List<Meal>>{
          today: <Meal>[meal('Käsespätzle')],
        },
        'am-tierpark': <DateTime, List<Meal>>{
          today: <Meal>[meal('Linsen')],
        },
      },
    );
    await settle(container);
    await container
        .read(notificationSettingsProvider.notifier)
        .setOptedIn(true);
    await container
        .read(canteenFilterProvider.notifier)
        .toggleFavourite(meal('Käsespätzle'));

    expect(await canteenFavouriteKeysOf(container), isEmpty);
  });

  test('without the opt-in nothing is planned at all', () async {
    final ProviderContainer container = containerFor(
      slug: 'fasanerieallee',
      menus: <String, Map<DateTime, List<Meal>>>{
        'fasanerieallee': <DateTime, List<Meal>>{
          today: <Meal>[meal('Käsespätzle')],
        },
      },
    );
    await settle(container);
    await container
        .read(canteenFilterProvider.notifier)
        .toggleFavourite(meal('Käsespätzle'));

    expect(await canteenFavouriteKeysOf(container), isEmpty);
  });
}
