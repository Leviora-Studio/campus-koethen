// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/locale/formatters.dart';
import '../../../core/locale/locale_providers.dart';
import '../../../core/network/loaded.dart';
import '../../../l10n/l10n.dart';
import '../../canteen/application/canteen_filter_controller.dart';
import '../../canteen/application/canteen_providers.dart';
import '../../canteen/data/canteen_models.dart';
import '../../canteen/domain/canteen_filter.dart';
import '../domain/notification_category.dart';
import '../domain/notification_request.dart';
import 'notification_providers.dart';
import 'notification_tap_router.dart';

/// N3 · `canteen.favourite` — the 11:00 hint about a favourite dish
/// (ADR-0001 § 7.3, P6).
///
/// Everything this category needs is already on the device: the menu of the
/// preferred canteen sits in the content cache, and the favourites are a list
/// of **dish names** in `shared_preferences`. Nothing is uploaded, nothing is
/// registered, and no dish name leaves the device — the match happens here,
/// and the only place a name ends up is the text of a notification the reader
/// asked for.
abstract final class CanteenFavouriteCandidates {
  /// The hour of the hint. Fixed, inside the delivery window by construction.
  static const int hour = 11;

  /// How old a cached menu may be before it stops producing hints.
  ///
  /// The planner never fetches (ADR-0001 § 7.2), so the only question it can
  /// answer is "what did the app last see". Half the cached window is the
  /// bound: within a week the menu is worth telling somebody about, and beyond
  /// it the app would be promising a dish it has not checked since — which is
  /// exactly the promise the non-goals rule out. An expired cache produces no
  /// candidates at all, and because the plan is a whole target state, that
  /// cancels the pending hints rather than leaving them behind.
  static const Duration maxMenuAge = Duration(days: 7);

  /// How many characters of a dish name a notification body may carry.
  ///
  /// A canteen name can run to a full sentence with extras and garnishes. The
  /// operating system truncates a long body without asking, and it does it
  /// mid-word — so the cut is made here, at a word boundary, where the result
  /// is still a name somebody recognises.
  static const int maxDishNameLength = 60;

  /// Builds the candidates for one planning run.
  ///
  /// Pure, and deliberately so: menu, favourites, "now" and the translations
  /// are all arguments, so "two dishes with the same name, one of them long,
  /// on a day whose menu is six days old" is a unit test rather than a device
  /// session.
  ///
  /// Exactly **one** request per canteen and offering day, no matter how many
  /// dishes match — that is not bundling in the sense of P8, it is what P6
  /// describes. Several matches are summarised inside that one text.
  static List<NotificationRequest> build({
    required CanteenMenu menu,
    required Set<String> favourites,
    required DateTime now,
    required AppLocalizations l10n,
    required String locale,
    String priceGroup = MealPrice.studentGroup,
    DateTime? menuCachedAt,
  }) {
    if (favourites.isEmpty) return const <NotificationRequest>[];
    if (menuCachedAt != null && now.difference(menuCachedAt) > maxMenuAge) {
      return const <NotificationRequest>[];
    }

    // Normalised once, not per dish: the store keeps the name as it was
    // published, and a menu re-published with different spacing or casing is
    // still the same dish to a reader.
    final Set<String> wanted = favourites
        .map(_normalise)
        .where((String name) => name.isNotEmpty)
        .toSet();
    if (wanted.isEmpty) return const <NotificationRequest>[];

    final DateTime today = DateTime(now.year, now.month, now.day);
    final List<NotificationRequest> requests = <NotificationRequest>[];

    for (final MenuDay day in menu.days) {
      if (day.date.isBefore(today)) continue;

      // Keyed by the normalised name, so a day that lists the same dish at two
      // counters counts once and is never named twice in the text.
      final Map<String, Meal> matches = <String, Meal>{};
      for (final Meal meal in day.meals) {
        final String key = _normalise(meal.name);
        if (!wanted.contains(key)) continue;
        matches.putIfAbsent(key, () => meal);
      }
      if (matches.isEmpty) continue;

      final Meal first = matches.values.first;
      final int more = matches.length - 1;
      final String dish = _shorten(first.name);
      final String canteen = menu.displayName;

      final String body;
      if (more > 0) {
        body = l10n.notificationCanteenFavouriteBodyMore(canteen, dish, more);
      } else {
        final MealPrice? mealPrice = first.priceFor(priceGroup);
        // A dish without a price for the reader's own group is named without
        // one. Another group's number would be a different person's price.
        final String? price = mealPrice == null
            ? null
            : MoneyFormatter.format(
                amount: mealPrice.amount,
                currencyCode: mealPrice.currency,
                locale: locale,
              );
        body = price == null
            ? l10n.notificationCanteenFavouriteBody(canteen, dish)
            : l10n.notificationCanteenFavouriteBodyWithPrice(
                canteen,
                dish,
                price,
              );
      }

      requests.add(
        NotificationRequest(
          category: NotificationCategory.canteenFavourite,
          // Canteen and day, never the dish: the hint is about the day, and
          // its identity must not change because a different favourite
          // matched. The dish rides along in `detail`, for the tap only.
          target: '${menu.canteenSlug}:${notificationDayKey(day.date)}',
          detail: first.name,
          trigger: LocalTimeTrigger(day: day.date, hour: hour),
          title: more > 0
              ? l10n.notificationCanteenFavouriteTitleMultiple
              : l10n.notificationCanteenFavouriteTitle,
          body: body,
          // A dish name and a canteen are published on a board in a public
          // hall. Nothing here needs hiding on a lock screen (ADR-0001 § 7.7).
          visibility: NotificationVisibility.publicContent,
        ),
      );
    }

    return List<NotificationRequest>.unmodifiable(requests);
  }

  /// Case- and whitespace-insensitive form of a dish name.
  ///
  /// Matching is by name and nothing else (ADR-0001 § 4.1, finding 5). A
  /// favourite starred in German does not match the English menu, and that is
  /// stated rather than papered over: translating dish names on the device
  /// would invent matches the reader never made.
  static final RegExp _whitespaceRun = RegExp(r'\s+');

  static String _normalise(String value) =>
      value.trim().toLowerCase().replaceAll(_whitespaceRun, ' ');

  /// [value], cut at a word boundary once it grows past
  /// [maxDishNameLength].
  static String _shorten(String value) {
    final String name = value.trim();
    if (name.length <= maxDishNameLength) return name;
    final String cut = name.substring(0, maxDishNameLength);
    final int space = cut.lastIndexOf(' ');
    // A single word longer than the limit has no boundary to cut at; the hard
    // cut is then the honest answer, and the ellipsis says so either way.
    final String head = space > maxDishNameLength ~/ 2
        ? cut.substring(0, space)
        : cut;
    return '$head…';
  }
}

/// The N3 candidates of the current app state.
///
/// Watches the preferred canteen, its cached menu, the favourites and the
/// language. Every one of those is a re-planning trigger of ADR-0001 § 7.1,
/// and none of them needs a trigger list: a change rebuilds this provider,
/// which rebuilds the plan, which replaces what the operating system holds.
final Provider<List<NotificationRequest>> canteenFavouriteCandidatesProvider =
    Provider<List<NotificationRequest>>((Ref ref) {
      final String? slug = ref.watch(selectedCanteenSlugProvider);
      if (slug == null) return const <NotificationRequest>[];

      // `.value` and not `.requireValue`: while the menu is loading, or after
      // it failed with nothing cached, there is no local menu — and no local
      // menu means no hint, never a fetch.
      final Loaded<CanteenMenu>? menu = ref
          .watch(canteenMenuProvider(slug))
          .value;
      if (menu == null) return const <NotificationRequest>[];

      final CanteenFilter filter = ref.watch(canteenFilterProvider);
      return CanteenFavouriteCandidates.build(
        menu: menu.value,
        favourites: filter.favourites,
        now: ref.watch(notificationClockProvider).now(),
        l10n: ref.watch(appLocalizationsProvider),
        locale: ref.watch(localeCodeProvider),
        priceGroup: filter.priceGroup,
        menuCachedAt: menu.fromCache ? menu.cachedAt : null,
      );
    });
