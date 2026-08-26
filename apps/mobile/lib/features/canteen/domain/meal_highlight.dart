// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:meta/meta.dart';

/// The one dish the canteen screen should mark, because the reader arrived
/// from a notification about it (ADR-0001 § 7.8).
///
/// Keyed by **name**, like the favourites themselves: `Meal.id` changes every
/// time a dish is re-published, so an id kept in a notification payload for a
/// week would stop matching the very dish it was written for
/// (ADR-0001 § 4.1, finding 5).
///
/// It carries the canteen and the day it belongs to so that it can only ever
/// be shown where it means something. A highlight that outlived its context
/// would put a marker on an unrelated card.
@immutable
class MealHighlight {
  MealHighlight({
    required this.canteenSlug,
    required DateTime day,
    required this.mealName,
  }) : day = DateTime(day.year, day.month, day.day);

  final String canteenSlug;
  final DateTime day;
  final String mealName;

  /// Whether this highlight applies to [name] on the page currently shown.
  bool marks({
    required String? slug,
    required DateTime shownDay,
    required String name,
  }) =>
      slug == canteenSlug &&
      shownDay.year == day.year &&
      shownDay.month == day.month &&
      shownDay.day == day.day &&
      name == mealName;

  @override
  bool operator ==(Object other) =>
      other is MealHighlight &&
      other.canteenSlug == canteenSlug &&
      other.day == day &&
      other.mealName == mealName;

  @override
  int get hashCode => Object.hash(canteenSlug, day, mealName);
}
