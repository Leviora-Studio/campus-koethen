// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:meta/meta.dart';

import 'notification_category.dart';
import 'planned_notification.dart';

/// The number of notifications the app keeps pre-registered at once.
///
/// iOS caps how many local notifications one app may have pending — the
/// documented figure is 64, and it is to be **measured** against the platform
/// version in use rather than trusted (ADR-0001 § 13.2). Sixty leaves the
/// margin: hitting the real ceiling would make the operating system drop
/// entries of its own choosing, which is exactly the non-determinism the
/// planner exists to avoid.
const int kMaxScheduledNotifications = 60;

/// Why a candidate did not become a planned notification.
///
/// A counter per reason, not a log of the entries themselves: a dropped
/// candidate carries an event title or a dish name, and neither belongs in a
/// diagnostic record.
enum NotificationDropReason {
  /// The reader has notifications switched off entirely, or the operating
  /// system has not granted permission.
  notPermitted,

  /// The reader switched this category off.
  categoryDisabled,

  /// The moment had already passed. Missed reminders are never caught up —
  /// a reminder about yesterday is noise (ADR-0001 § 9.4).
  inThePast,

  /// A second candidate carried a key an earlier one already used. The first
  /// wins; the sort is deterministic, so "first" is a defined entry.
  duplicateKey,

  /// A fixed-time category asked for a moment outside the 07:00–20:00 window.
  /// By construction this cannot happen for 08:00 and 11:00, so it means a
  /// contributor is wrong — dropped loudly rather than silently moved.
  outsideDeliveryWindow,

  /// The budget of [kMaxScheduledNotifications] was full. The entry is not
  /// lost: the next planning run schedules it as earlier ones fall due.
  budgetExhausted,
}

/// What one planning run decided, and what it had to leave out.
///
/// Deliberately free of any content: category counts and drop counts only.
/// It exists so that "the budget was exhausted" is a number somebody can read
/// rather than a silent truncation (ADR-0001 § 7.5).
@immutable
class NotificationPlanDiagnostics {
  const NotificationPlanDiagnostics({
    required this.candidateCount,
    required this.scheduledCount,
    required this.scheduledByCategory,
    required this.dropped,
    required this.budget,
  });

  const NotificationPlanDiagnostics.empty()
    : candidateCount = 0,
      scheduledCount = 0,
      scheduledByCategory = const <NotificationCategory, int>{},
      dropped = const <NotificationDropReason, int>{},
      budget = kMaxScheduledNotifications;

  final int candidateCount;
  final int scheduledCount;
  final Map<NotificationCategory, int> scheduledByCategory;
  final Map<NotificationDropReason, int> dropped;
  final int budget;

  int droppedFor(NotificationDropReason reason) => dropped[reason] ?? 0;

  /// Whether the run ran into the budget ceiling. A fact worth surfacing:
  /// it is the early indicator that the iOS limit is being approached.
  bool get budgetExhausted =>
      droppedFor(NotificationDropReason.budgetExhausted) > 0;

  /// A single line for the developer log. Counts only — no key, no title, no
  /// date, nothing that could identify a course, a dish or a reader.
  String toLogLine() {
    final String perCategory = NotificationCategory.values
        .map(
          (NotificationCategory c) =>
              '${c.keyPrefix}=${scheduledByCategory[c] ?? 0}',
        )
        .join(' ');
    final String drops = NotificationDropReason.values
        .where((NotificationDropReason r) => droppedFor(r) > 0)
        .map((NotificationDropReason r) => '${r.name}=${droppedFor(r)}')
        .join(' ');
    return 'notifications: candidates=$candidateCount scheduled=$scheduledCount/'
        '$budget $perCategory${drops.isEmpty ? '' : ' dropped[$drops]'}';
  }
}

/// The complete set of notifications that should currently be registered with
/// the operating system, plus what it cost to arrive at it.
///
/// A **whole** target state, never a delta: a full state cannot drift apart,
/// a delta can (ADR-0001 § 7.1).
@immutable
class NotificationPlan {
  const NotificationPlan({
    required this.notifications,
    required this.diagnostics,
  });

  const NotificationPlan.empty()
    : notifications = const <PlannedNotification>[],
      diagnostics = const NotificationPlanDiagnostics.empty();

  final List<PlannedNotification> notifications;
  final NotificationPlanDiagnostics diagnostics;

  bool get isEmpty => notifications.isEmpty;

  @override
  bool operator ==(Object other) =>
      other is NotificationPlan &&
      other.notifications.length == notifications.length &&
      _sameEntries(other.notifications);

  bool _sameEntries(List<PlannedNotification> other) {
    for (int i = 0; i < notifications.length; i++) {
      if (other[i] != notifications[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(notifications);
}
