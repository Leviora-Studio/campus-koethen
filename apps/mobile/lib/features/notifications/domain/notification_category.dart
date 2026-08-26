// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

/// The notification categories the product release (LEVIORA-159) approved.
///
/// The set is closed: ADR-0001 § 7.3 lists exactly three, and P5 rules out
/// individual reminders for timetable slots and Moodle deadlines. Adding a
/// value here is a product decision, not a refactoring.
///
/// Every category carries its own identity in three places, and all three are
/// stable across app updates because they end up inside data the operating
/// system keeps:
///
/// * [key] — what a notification payload names (`v1|<key>|<target>`),
/// * [keyPrefix] — the first segment of a scheduling key (`n1:`, `n2:`, `n3:`),
/// * [channelId] — the Android notification channel.
///
/// [order] is the tie-breaker of the planner's deterministic sort, so two
/// notifications due at the very same instant always survive the budget in the
/// same order — see `notification_planner.dart`.
enum NotificationCategory {
  /// N1 · `event.reminder` — one reminder exactly 24 hours before a public or
  /// saved event (P3).
  eventReminder(
    key: 'event.reminder',
    keyPrefix: 'n1',
    channelId: 'events_channel',
    storageValue: 'events',
    order: 0,
    windowPolicy: DeliveryWindowPolicy.shiftIntoWindow,
  ),

  /// N2 · `daily.summary` — the 08:00 overview of the day (P4).
  dailySummary(
    key: 'daily.summary',
    keyPrefix: 'n2',
    channelId: 'summary_channel',
    storageValue: 'summary',
    order: 1,
    windowPolicy: DeliveryWindowPolicy.fixedLocalTime,
  ),

  /// N3 · `canteen.favourite` — the 11:00 hint about a favourite dish (P6).
  canteenFavourite(
    key: 'canteen.favourite',
    keyPrefix: 'n3',
    channelId: 'canteen_channel',
    storageValue: 'canteen',
    order: 2,
    windowPolicy: DeliveryWindowPolicy.fixedLocalTime,
  );

  const NotificationCategory({
    required this.key,
    required this.keyPrefix,
    required this.channelId,
    required this.storageValue,
    required this.order,
    required this.windowPolicy,
  });

  /// The category identifier used in a notification payload.
  final String key;

  /// First segment of every scheduling key of this category.
  final String keyPrefix;

  /// The Android notification channel this category posts to. Three channels,
  /// one per category, so a reader can silence one kind without silencing the
  /// rest. A channel is **not** a group key and does not bundle anything
  /// (ADR-0001 § 7.7, P8).
  final String channelId;

  /// Stable identifier for local storage, never the enum index.
  final String storageValue;

  /// Position in the planner's category tie-break order.
  final int order;

  /// How the delivery window (P7) applies to this category.
  final DeliveryWindowPolicy windowPolicy;

  static NotificationCategory? fromKey(String? value) {
    for (final NotificationCategory category in NotificationCategory.values) {
      if (category.key == value) return category;
    }
    return null;
  }

  static NotificationCategory? fromStorage(String? value) {
    for (final NotificationCategory category in NotificationCategory.values) {
      if (category.storageValue == value) return category;
    }
    return null;
  }
}

/// How a category relates to the 07:00–20:00 delivery window (P7).
enum DeliveryWindowPolicy {
  /// The desired instant is derived from a source date (an event start minus
  /// 24 hours), so it can fall outside the window and is moved to the next
  /// 07:00 — ADR-0001 § 7.4.
  shiftIntoWindow,

  /// The category names a fixed local wall-clock time that lies inside the
  /// window by construction (08:00, 11:00). Nothing is ever shifted; a request
  /// outside the window is a programming error and is dropped with a
  /// diagnostic rather than silently moved.
  fixedLocalTime,
}
