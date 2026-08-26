// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

/// Calendar week arithmetic for the timetable.
///
/// All values are **date-only** local `DateTime`s at midnight. Days are shifted
/// through the `DateTime(y, m, d + n)` constructor, which normalises month and
/// year boundaries and stays correct across daylight saving changes — unlike
/// adding a `Duration` to a local timestamp.
abstract final class TimetableWeek {
  /// Number of days one request covers. Well inside the contract's 42 day cap.
  static const int lengthInDays = 7;

  /// Midnight of the day [value] belongs to.
  static DateTime dayOf(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  /// Monday of the week [value] belongs to.
  static DateTime startOf(DateTime value) {
    final DateTime day = dayOf(value);
    return DateTime(day.year, day.month, day.day - (day.weekday - 1));
  }

  /// Sunday of the week [value] belongs to.
  static DateTime endOf(DateTime value) =>
      shift(startOf(value), lengthInDays - 1);

  /// All seven days of the week [value] belongs to, Monday first.
  static List<DateTime> daysOf(DateTime value) {
    final DateTime start = startOf(value);
    return <DateTime>[
      for (int offset = 0; offset < lengthInDays; offset++)
        shift(start, offset),
    ];
  }

  /// [value] moved by [days] calendar days.
  static DateTime shift(DateTime value, int days) =>
      DateTime(value.year, value.month, value.day + days);
}
