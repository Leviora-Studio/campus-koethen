// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:intl/intl.dart';

/// Locale-aware date and time formatting.
///
/// The generated localisations receive **pre-formatted strings**, which keeps
/// the ARB files free of locale-specific date patterns while still producing
/// correct output for `de` and `en`.
abstract final class AppDateFormats {
  // `DateFormat` parses its pattern/locale symbols on construction, and these
  // helpers are called per rendered row in calendar, timetable and mail
  // lists. Caching one instance per (kind, locale) avoids re-parsing on every
  // call without changing any formatted output.
  static final Map<String, DateFormat> _cache = <String, DateFormat>{};

  static DateFormat _cached(
    String kind,
    String locale,
    DateFormat Function() create,
  ) => _cache['$kind|$locale'] ??= create();

  /// e.g. `22. Juli 2026` · `July 22, 2026`
  static String longDate(DateTime value, String locale) => _cached(
    'longDate',
    locale,
    () => DateFormat.yMMMMd(locale),
  ).format(value.toLocal());

  /// e.g. `Mittwoch, 22. Juli 2026` · `Wednesday, July 22, 2026`
  static String weekdayDate(DateTime value, String locale) => _cached(
    'weekdayDate',
    locale,
    () => DateFormat.yMMMMEEEEd(locale),
  ).format(value.toLocal());

  /// e.g. `22.07.2026, 14:05` · `Jul 22, 2026 14:05`
  static String dateTime(DateTime value, String locale) => _cached(
    'dateTime',
    locale,
    () => DateFormat.yMMMd(locale).add_Hm(),
  ).format(value.toLocal());

  /// Short weekday plus date, used by the canteen day navigation.
  static String shortWeekdayDate(DateTime value, String locale) => _cached(
    'shortWeekdayDate',
    locale,
    () => DateFormat.MEd(locale),
  ).format(value.toLocal());

  /// e.g. `Mo` · `Mon` — the abbreviated weekday of the day selector.
  static String shortWeekday(DateTime value, String locale) => _cached(
    'shortWeekday',
    locale,
    () => DateFormat.E(locale),
  ).format(value.toLocal());

  /// e.g. `20` — the day of month of the day selector.
  static String dayOfMonth(DateTime value, String locale) => _cached(
    'dayOfMonth',
    locale,
    () => DateFormat.d(locale),
  ).format(value.toLocal());

  /// e.g. `20.07.2026` · `Jul 20, 2026` — compact, for a timestamp that is too
  /// old for a relative form to help.
  static String shortDate(DateTime value, String locale) => _cached(
    'shortDate',
    locale,
    () => DateFormat.yMd(locale),
  ).format(value.toLocal());

  /// e.g. `20. Juli` · `Jul 20` — one end of a week range.
  static String dayAndMonth(DateTime value, String locale) => _cached(
    'dayAndMonth',
    locale,
    () => DateFormat.MMMd(locale),
  ).format(value.toLocal());

  /// e.g. `Mai 2026` · `May 2026` — which week the strip is showing.
  static String monthAndYear(DateTime value, String locale) => _cached(
    'monthAndYear',
    locale,
    () => DateFormat.yMMMM(locale),
  ).format(value.toLocal());

  /// e.g. `08:00` — the wall clock time of an appointment in the **device's**
  /// time zone. Uses the same 24 hour pattern as [dateTime] so times read the
  /// same everywhere in the app.
  static String time(DateTime value, String locale) => _cached(
    'time',
    locale,
    () => DateFormat.Hm(locale),
  ).format(value.toLocal());

  /// `YYYY-MM-DD` — the wire format of the API. Never shown to users.
  static String isoDate(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

/// Locale-aware money formatting **without floating point arithmetic**.
///
/// The API delivers amounts as decimal strings (`"1.95"`) so that no binary
/// rounding can happen on the wire. This formatter keeps that guarantee: the
/// digits of the fractional part are copied verbatim from the input string and
/// only the *integer* part — which is exactly representable as an `int` — is
/// passed through `NumberFormat` for digit grouping. The currency symbol and
/// its placement come from the locale data.
abstract final class MoneyFormatter {
  static final Map<String, NumberFormat> _currencyCache =
      <String, NumberFormat>{};
  static final Map<String, NumberFormat> _decimalCache =
      <String, NumberFormat>{};

  static NumberFormat _cachedCurrency(
    String locale,
    String currencyCode,
    int decimalDigits,
  ) => _currencyCache['$locale|$currencyCode|$decimalDigits'] ??=
      NumberFormat.simpleCurrency(
        locale: locale,
        name: currencyCode,
        decimalDigits: decimalDigits,
      );

  static NumberFormat _cachedDecimal(String locale) =>
      _decimalCache[locale] ??= NumberFormat.decimalPattern(locale);

  /// Formats [amount] (a plain decimal string) for [locale].
  ///
  /// Returns `null` if [amount] is not a plain decimal number so callers can
  /// show an explicit "no price" label instead of rendering garbage.
  static String? format({
    required String amount,
    required String currencyCode,
    required String locale,
  }) {
    final _DecimalParts? parts = _DecimalParts.parse(amount);
    if (parts == null) return null;

    final NumberFormat currency = _cachedCurrency(
      locale,
      currencyCode,
      parts.fraction.length,
    );
    final String decimalSeparator = currency.symbols.DECIMAL_SEP;

    // Grouping of the integer part: exact, because `integerValue` is an int.
    final String integerText = _cachedDecimal(
      locale,
    ).format(parts.integerValue);

    final StringBuffer number = StringBuffer();
    if (parts.isNegative) number.write(currency.symbols.MINUS_SIGN);
    number.write(integerText);
    if (parts.fraction.isNotEmpty) {
      number
        ..write(decimalSeparator)
        ..write(parts.fraction);
    }

    // `currency.format(0)` renders the locale's currency layout around a known
    // zero amount. Swapping the zero digits for our exact digits preserves the
    // symbol position, the spacing and any non-breaking space.
    final String template = currency.format(0);
    final String zeroDigits = parts.fraction.isEmpty
        ? '0'
        : '0$decimalSeparator${'0' * parts.fraction.length}';
    if (!template.contains(zeroDigits)) {
      // Defensive: unknown locale layout — still return something correct.
      return '${number.toString()} $currencyCode';
    }
    return template.replaceFirst(zeroDigits, number.toString());
  }
}

class _DecimalParts {
  const _DecimalParts({
    required this.isNegative,
    required this.integerValue,
    required this.fraction,
  });

  final bool isNegative;
  final int integerValue;
  final String fraction;

  static final RegExp _pattern = RegExp(r'^(-?)(\d{1,15})(?:\.(\d{1,6}))?$');

  static _DecimalParts? parse(String raw) {
    final RegExpMatch? match = _pattern.firstMatch(raw.trim());
    if (match == null) return null;
    final int? integerValue = int.tryParse(match.group(2)!);
    if (integerValue == null) return null;
    return _DecimalParts(
      isNegative: match.group(1) == '-',
      integerValue: integerValue,
      fraction: match.group(3) ?? '',
    );
  }
}
