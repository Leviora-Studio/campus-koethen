// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:meta/meta.dart';
import 'package:timezone/timezone.dart' as tz;

import 'notification_category.dart';
import 'notification_payload.dart';
import 'notification_request.dart';

/// One notification the planner decided to hand to the operating system.
///
/// Everything about it is settled: the zone-correct instant, the finished
/// text, the payload and the identity. The scheduler adds no decisions of its
/// own — it only translates.
@immutable
class PlannedNotification {
  const PlannedNotification({
    required this.key,
    required this.category,
    required this.scheduledAt,
    required this.title,
    required this.body,
    required this.payload,
    required this.visibility,
  });

  /// The stable scheduling key of ADR-0001 § 7.6, e.g. `n2:2026-09-03`.
  final String key;

  final NotificationCategory category;

  /// The zone-aware instant the operating system is asked for.
  final tz.TZDateTime scheduledAt;

  final String title;
  final String body;
  final NotificationPayload payload;
  final NotificationVisibility visibility;

  /// The integer identifier the platforms require, as a deterministic 31-bit
  /// hash of [key].
  ///
  /// Deterministic so that a given reminder keeps the same id across runs,
  /// which is what makes a log line about it followable. Correctness does not
  /// rest on it: every run cancels everything and re-schedules from scratch
  /// (ADR-0001 § 7.1), so even a collision could not produce a duplicate or a
  /// stale entry.
  int get systemId => notificationSystemId(key);

  @override
  bool operator ==(Object other) =>
      other is PlannedNotification &&
      other.key == key &&
      other.category == category &&
      other.scheduledAt == scheduledAt &&
      other.title == title &&
      other.body == body &&
      other.payload == payload &&
      other.visibility == visibility;

  @override
  int get hashCode =>
      Object.hash(key, category, scheduledAt, title, body, payload, visibility);

  /// Diagnostic form. Names the key and the instant — never the title or the
  /// body, which may carry a dish name or an event title.
  @override
  String toString() =>
      'PlannedNotification($key @ ${scheduledAt.toIso8601String()})';
}

/// A deterministic, positive 31-bit identifier for a scheduling key.
///
/// FNV-1a over the UTF-16 code units, masked to 31 bits so the value is a
/// valid non-negative `int` on both platforms and survives the plugin's
/// 32-bit signed integer channel.
int notificationSystemId(String key) {
  const int offsetBasis = 0x811c9dc5;
  const int prime = 0x01000193;
  int hash = offsetBasis;
  for (int i = 0; i < key.length; i++) {
    hash = (hash ^ key.codeUnitAt(i)) & 0xffffffff;
    hash = (hash * prime) & 0xffffffff;
  }
  return hash & 0x7fffffff;
}
