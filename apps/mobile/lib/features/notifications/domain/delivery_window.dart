// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:timezone/timezone.dart' as tz;

/// The approved delivery window, 07:00–20:00 local time (P7).
///
/// Both bounds are **inclusive**. 07:00:00 and 20:00:00 are inside the window;
/// that convention makes the rule single-valued and is an architecture
/// decision for unambiguity, not a product rule of its own
/// (ADR-0001 § 7.4).
abstract final class DeliveryWindow {
  static const int startHour = 7;
  static const int endHour = 20;

  /// Whether [moment] lies inside the window.
  static bool allows(tz.TZDateTime moment) {
    if (moment.hour < startHour) return false;
    if (moment.hour > endHour) return false;
    if (moment.hour == endHour) {
      // 20:00:00 exactly is allowed; 20:00:01 is not.
      return moment.minute == 0 &&
          moment.second == 0 &&
          moment.millisecond == 0 &&
          moment.microsecond == 0;
    }
    return true;
  }

  /// The moment [desired] is actually delivered at, per P7.
  ///
  /// ```text
  /// inside the window        → unchanged
  /// before 07:00             → 07:00 of the same day
  /// after 20:00              → 07:00 of the next day
  /// ```
  ///
  /// The rule is total and single-valued: every input has exactly one result,
  /// and a shifted reminder is never pushed past the event it is about — the
  /// largest shift arises just before midnight and is a little over seven
  /// hours, which still leaves more than sixteen hours of lead time.
  ///
  /// The result is rebuilt through the [tz.TZDateTime] constructor rather than
  /// by adding a `Duration`, so a shift across a daylight-saving change lands
  /// on 07:00 on the dial instead of 06:00 or 08:00.
  static tz.TZDateTime shiftIntoWindow(tz.TZDateTime desired) {
    if (allows(desired)) return desired;
    final tz.Location location = desired.location;
    if (desired.hour < startHour) {
      return tz.TZDateTime(
        location,
        desired.year,
        desired.month,
        desired.day,
        startHour,
      );
    }
    return tz.TZDateTime(
      location,
      desired.year,
      desired.month,
      desired.day + 1,
      startHour,
    );
  }
}
