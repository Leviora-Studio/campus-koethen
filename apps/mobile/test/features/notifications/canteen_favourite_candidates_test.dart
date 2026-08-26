// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:campus_koethen/features/canteen/data/canteen_models.dart';
import 'package:campus_koethen/features/notifications/application/canteen_favourite_candidates.dart';
import 'package:campus_koethen/features/notifications/domain/notification_category.dart';
import 'package:campus_koethen/features/notifications/domain/notification_payload.dart';
import 'package:campus_koethen/features/notifications/domain/notification_request.dart';
import 'package:campus_koethen/l10n/l10n.dart';
import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_test/flutter_test.dart';

/// N3 is a pure match between two things that are already on the device: the
/// cached menu and a list of dish names. Everything the issue asks about —
/// duplicate names, an empty or expired cache, several matches on one day,
/// a menu that changed — is therefore a unit test and not a device session.

final AppLocalizations de = lookupAppLocalizations(const Locale('de'));
final AppLocalizations en = lookupAppLocalizations(const Locale('en'));

Meal meal(String name, {String? amount = '2.80', String group = 'student'}) =>
    Meal(
      id: 'id-$name-$amount',
      name: name,
      prices: amount == null
          ? const <MealPrice>[]
          : <MealPrice>[
              MealPrice(
                group: group,
                label: group,
                amount: amount,
                currency: 'EUR',
              ),
            ],
    );

CanteenMenu menuWith(Map<DateTime, List<Meal>> days) => CanteenMenu(
  canteenSlug: 'mensa-fasanerieallee',
  displayName: 'Mensa Fasanerieallee',
  days: <MenuDay>[
    for (final MapEntry<DateTime, List<Meal>> entry in days.entries)
      MenuDay(date: entry.key, meals: entry.value),
  ],
);

final DateTime today = DateTime(2026, 9, 3);
final DateTime tomorrow = DateTime(2026, 9, 4);
final DateTime yesterday = DateTime(2026, 9, 2);
final DateTime now = DateTime(2026, 9, 3, 7, 30);

List<NotificationRequest> build({
  required CanteenMenu menu,
  Set<String> favourites = const <String>{'Käsespätzle'},
  DateTime? at,
  AppLocalizations? l10n,
  String locale = 'de',
  String priceGroup = 'student',
  DateTime? cachedAt,
}) => CanteenFavouriteCandidates.build(
  menu: menu,
  favourites: favourites,
  now: at ?? now,
  l10n: l10n ?? de,
  locale: locale,
  priceGroup: priceGroup,
  menuCachedAt: cachedAt,
);

void main() {
  group('matching by dish name', () {
    test('a favourite on the menu becomes exactly one 11:00 candidate', () {
      final List<NotificationRequest> requests = build(
        menu: menuWith(<DateTime, List<Meal>>{
          today: <Meal>[meal('Linsen'), meal('Käsespätzle')],
        }),
      );

      expect(requests, hasLength(1));
      final NotificationRequest request = requests.single;
      expect(request.category, NotificationCategory.canteenFavourite);
      expect(
        request.trigger,
        LocalTimeTrigger(day: DateTime(2026, 9, 3), hour: 11),
      );
      expect(request.key, 'n3:mensa-fasanerieallee:2026-09-03');
      expect(request.body, contains('Käsespätzle'));
      expect(request.body, contains('Mensa Fasanerieallee'));
    });

    test('matching ignores case and stray whitespace, never Meal.id', () {
      final List<NotificationRequest> requests = build(
        favourites: const <String>{'  käse  spätzle '},
        menu: menuWith(<DateTime, List<Meal>>{
          today: <Meal>[meal('Käse Spätzle')],
        }),
      );

      expect(requests, hasLength(1));
    });

    test('a dish that is not a favourite produces nothing', () {
      expect(
        build(
          menu: menuWith(<DateTime, List<Meal>>{
            today: <Meal>[meal('Linsen')],
          }),
        ),
        isEmpty,
      );
    });

    test('the same name at two counters is still one candidate, named once', () {
      final List<NotificationRequest> requests = build(
        menu: menuWith(<DateTime, List<Meal>>{
          today: <Meal>[
            meal('Käsespätzle'),
            meal('Käsespätzle', amount: '3.40'),
          ],
        }),
      );

      expect(requests, hasLength(1));
      expect('Käsespätzle'.allMatches(requests.single.body), hasLength(1));
      // One dish, not "and one more favourite": the duplicate is the same dish.
      expect(requests.single.title, de.notificationCanteenFavouriteTitle);
    });
  });

  group('nothing to say', () {
    test('no favourites at all', () {
      expect(
        build(
          favourites: const <String>{},
          menu: menuWith(<DateTime, List<Meal>>{
            today: <Meal>[meal('Käsespätzle')],
          }),
        ),
        isEmpty,
      );
    });

    test('a favourite that is only whitespace is not a favourite', () {
      expect(
        build(
          favourites: const <String>{'   '},
          menu: menuWith(<DateTime, List<Meal>>{
            today: <Meal>[meal('Käsespätzle')],
          }),
        ),
        isEmpty,
      );
    });

    test('an empty menu cache', () {
      expect(build(menu: menuWith(<DateTime, List<Meal>>{})), isEmpty);
    });

    test('a day with no meals is a real, empty day', () {
      expect(
        build(menu: menuWith(<DateTime, List<Meal>>{today: <Meal>[]})),
        isEmpty,
      );
    });

    test('days already past are never planned', () {
      final List<NotificationRequest> requests = build(
        menu: menuWith(<DateTime, List<Meal>>{
          yesterday: <Meal>[meal('Käsespätzle')],
        }),
      );

      expect(requests, isEmpty);
    });
  });

  group('an expired cache says nothing rather than something stale', () {
    test('a menu older than the limit produces no candidates', () {
      final List<NotificationRequest> requests = build(
        menu: menuWith(<DateTime, List<Meal>>{
          tomorrow: <Meal>[meal('Käsespätzle')],
        }),
        cachedAt: now.subtract(
          CanteenFavouriteCandidates.maxMenuAge + const Duration(minutes: 1),
        ),
      );

      expect(requests, isEmpty);
    });

    test('a menu inside the limit still produces them', () {
      final List<NotificationRequest> requests = build(
        menu: menuWith(<DateTime, List<Meal>>{
          tomorrow: <Meal>[meal('Käsespätzle')],
        }),
        cachedAt: now.subtract(
          CanteenFavouriteCandidates.maxMenuAge - const Duration(hours: 1),
        ),
      );

      expect(requests, hasLength(1));
    });
  });

  group('several matches stay one hint', () {
    test('one candidate per day, summarised, with the plural title', () {
      final List<NotificationRequest> requests = build(
        favourites: const <String>{'Käsespätzle', 'Linsen', 'Grünkohl'},
        menu: menuWith(<DateTime, List<Meal>>{
          today: <Meal>[meal('Käsespätzle'), meal('Linsen'), meal('Grünkohl')],
        }),
      );

      expect(requests, hasLength(1));
      expect(
        requests.single.title,
        de.notificationCanteenFavouriteTitleMultiple,
      );
      expect(requests.single.body, contains('Käsespätzle'));
      expect(requests.single.body, contains('2 weitere'));
      // The other names stay out of the text: two long names in a body the
      // system truncates would lose both.
      expect(requests.single.body, isNot(contains('Grünkohl')));
    });

    test('one candidate per offering day, each at 11:00', () {
      final List<NotificationRequest> requests = build(
        menu: menuWith(<DateTime, List<Meal>>{
          today: <Meal>[meal('Käsespätzle')],
          tomorrow: <Meal>[meal('Käsespätzle')],
        }),
      );

      expect(requests.map((NotificationRequest r) => r.key), <String>[
        'n3:mensa-fasanerieallee:2026-09-03',
        'n3:mensa-fasanerieallee:2026-09-04',
      ]);
      expect(
        requests.every(
          (NotificationRequest r) => (r.trigger as LocalTimeTrigger).hour == 11,
        ),
        isTrue,
      );
    });
  });

  group('the text', () {
    test('names the price of the reader\'s own group when there is one', () {
      final List<NotificationRequest> requests = build(
        menu: menuWith(<DateTime, List<Meal>>{
          today: <Meal>[meal('Käsespätzle', amount: '2.80')],
        }),
      );

      expect(requests.single.body, contains('2,80'));
    });

    test('says the dish without a price when that group has none', () {
      final List<NotificationRequest> requests = build(
        menu: menuWith(<DateTime, List<Meal>>{
          today: <Meal>[meal('Käsespätzle', group: 'guest')],
        }),
      );

      expect(requests.single.body, contains('Käsespätzle'));
      expect(requests.single.body, isNot(contains('2,80')));
    });

    test('is written in the language handed to it', () {
      final List<NotificationRequest> requests = build(
        l10n: en,
        locale: 'en',
        menu: menuWith(<DateTime, List<Meal>>{
          today: <Meal>[meal('Cheese Spaetzle')],
        }),
        favourites: const <String>{'Cheese Spaetzle'},
      );

      expect(requests.single.title, en.notificationCanteenFavouriteTitle);
      expect(requests.single.body, contains('Cheese Spaetzle'));
      expect(requests.single.body, contains('€'));
    });

    test('hedges: the menu can still change after the app last saw it', () {
      final List<NotificationRequest> requests = build(
        menu: menuWith(<DateTime, List<Meal>>{
          today: <Meal>[meal('Käsespätzle')],
        }),
      );

      expect(requests.single.body, contains('laut Speiseplan'));
    });

    test('a very long name is cut at a word boundary, not mid-word', () {
      const String long =
          'Käsespätzle mit Röstzwiebeln, glasierten Möhren und einem '
          'kleinen Salat der Saison';
      final List<NotificationRequest> requests = build(
        favourites: const <String>{long},
        menu: menuWith(<DateTime, List<Meal>>{
          today: <Meal>[meal(long)],
        }),
      );

      final NotificationRequest request = requests.single;
      expect(request.body, contains('…'));
      expect(request.body, isNot(contains('Salat der Saison')));
      // The payload keeps the full name — it is what the screen matches on.
      expect(request.detail, long);
    });
  });

  group('the payload', () {
    test(
      'carries canteen, day and the dish, while the key carries only two',
      () {
        final NotificationRequest request = build(
          menu: menuWith(<DateTime, List<Meal>>{
            today: <Meal>[meal('Käsespätzle')],
          }),
        ).single;

        expect(request.key, 'n3:mensa-fasanerieallee:2026-09-03');
        expect(
          request.payload.toStorage(),
          'v1|canteen.favourite|mensa-fasanerieallee:2026-09-03:Käsespätzle',
        );
        expect(
          NotificationPayload.tryParse(request.payload.toStorage())?.category,
          NotificationCategory.canteenFavourite,
        );
      },
    );

    test(
      'a name carrying the payload separator drops the dish, not the hint',
      () {
        final NotificationRequest request = build(
          favourites: const <String>{'Spätzle | Käse'},
          menu: menuWith(<DateTime, List<Meal>>{
            today: <Meal>[meal('Spätzle | Käse')],
          }),
        ).single;

        expect(
          request.payload.toStorage(),
          'v1|canteen.favourite|mensa-fasanerieallee:2026-09-03',
        );
      },
    );

    test('the key does not move when a different favourite matches', () {
      String keyFor(String dish) => build(
        favourites: const <String>{'Käsespätzle', 'Linsen'},
        menu: menuWith(<DateTime, List<Meal>>{
          today: <Meal>[meal(dish)],
        }),
      ).single.key;

      expect(keyFor('Käsespätzle'), keyFor('Linsen'));
    });
  });
}
