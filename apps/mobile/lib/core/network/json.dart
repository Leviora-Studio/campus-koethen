// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

/// Tolerant JSON readers used by the hand-written `fromJson` constructors.
///
/// Every reader degrades to `null` (or an empty collection) instead of
/// throwing. A malformed or unexpected field can therefore never take down a
/// screen — it simply disappears, which is exactly the behaviour the product
/// requires for optional content fields.
library;

Map<String, dynamic>? asJsonMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    final Map<String, dynamic> result = <String, dynamic>{};
    for (final MapEntry<dynamic, dynamic> entry in value.entries) {
      final Object? key = entry.key;
      result[key is String ? key : '$key'] = entry.value;
    }
    return result;
  }
  return null;
}

List<Map<String, dynamic>> asJsonMapList(Object? value) {
  if (value is! List) return const <Map<String, dynamic>>[];
  return value
      .map(asJsonMap)
      .whereType<Map<String, dynamic>>()
      .toList(growable: false);
}

List<Object?> asList(Object? value) =>
    value is List ? value : const <Object?>[];

/// Returns a non-empty trimmed string, or `null`.
///
/// Empty strings are treated as "not maintained" so the UI can hide the field
/// instead of rendering an empty row.
String? asString(Object? value) {
  if (value is! String) return null;
  final String trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

List<String> asStringList(Object? value) {
  if (value is! List) return const <String>[];
  return value.map(asString).whereType<String>().toList(growable: false);
}

int? asInt(Object? value) {
  if (value is int) return value;
  if (value is double && value.isFinite) return value.toInt();
  if (value is String) return int.tryParse(value.trim());
  return null;
}

/// Returns a finite double, or `null`.
///
/// JSON makes no difference between `4` and `4.0`, so an integer is accepted
/// too. Infinity and NaN are rejected: they would silently poison geometry.
double? asDouble(Object? value) {
  if (value is double) return value.isFinite ? value : null;
  if (value is int) return value.toDouble();
  if (value is String) {
    final double? parsed = double.tryParse(value.trim());
    return parsed != null && parsed.isFinite ? parsed : null;
  }
  return null;
}

bool? asBool(Object? value) {
  if (value is bool) return value;
  if (value is String) {
    if (value == 'true') return true;
    if (value == 'false') return false;
  }
  return null;
}

DateTime? asDateTime(Object? value) {
  final String? raw = asString(value);
  if (raw == null) return null;
  return DateTime.tryParse(raw);
}

final RegExp _calendarDatePattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

/// Parses a `YYYY-MM-DD` calendar date into a local midnight [DateTime].
DateTime? asCalendarDate(Object? value) {
  final String? raw = asString(value);
  if (raw == null) return null;
  final RegExpMatch? match = _calendarDatePattern.firstMatch(raw);
  if (match == null) return null;
  final int? year = int.tryParse(match.group(1)!);
  final int? month = int.tryParse(match.group(2)!);
  final int? day = int.tryParse(match.group(3)!);
  if (year == null || month == null || day == null) return null;
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  return DateTime(year, month, day);
}
