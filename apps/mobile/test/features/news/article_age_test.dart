// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:campus_koethen/features/news/domain/article_age.dart';
import 'package:flutter_test/flutter_test.dart';

final DateTime _now = DateTime.utc(2026, 8, 5, 12);

ArticleAge? _ageAfter(Duration elapsed) =>
    articleAge(_now.subtract(elapsed), now: _now);

void main() {
  test('no timestamp means no age — none is invented', () {
    expect(articleAge(null, now: _now), isNull);
  });

  group('the buckets', () {
    test('under a minute is "just now"', () {
      expect(_ageAfter(Duration.zero), const JustNow());
      expect(_ageAfter(const Duration(seconds: 59)), const JustNow());
    });

    test('minutes up to the hour', () {
      expect(_ageAfter(const Duration(minutes: 1)), const MinutesAgo(1));
      expect(_ageAfter(const Duration(minutes: 59)), const MinutesAgo(59));
    });

    test('hours up to the day', () {
      expect(_ageAfter(const Duration(hours: 1)), const HoursAgo(1));
      expect(_ageAfter(const Duration(hours: 23)), const HoursAgo(23));
    });

    test('days up to the week', () {
      expect(_ageAfter(const Duration(days: 1)), const DaysAgo(1));
      expect(_ageAfter(const Duration(days: 6)), const DaysAgo(6));
    });

    test('weeks up to the limit', () {
      expect(_ageAfter(const Duration(days: 7)), const WeeksAgo(1));
      expect(_ageAfter(const Duration(days: 20)), const WeeksAgo(2));
      expect(_ageAfter(const Duration(days: 27)), const WeeksAgo(3));
    });

    test('older than the limit switches to the date itself', () {
      // "vor 14 Wochen" says less than the date does.
      final DateTime old = _now.subtract(kRelativeAgeLimit);
      expect(articleAge(old, now: _now), OlderThanWeeks(old));
      expect(_ageAfter(const Duration(days: 400)), isA<OlderThanWeeks>());
    });
  });

  group('defensiveness', () {
    test('a future timestamp reads as "just now", not as a negative age', () {
      // Clocks disagree. A card saying "in 3 hours" for something the reader
      // can see right now looks broken.
      expect(
        articleAge(_now.add(const Duration(hours: 3)), now: _now),
        const JustNow(),
      );
      expect(
        articleAge(_now.add(const Duration(days: 400)), now: _now),
        const JustNow(),
      );
    });

    test('the clock is injected, so the result is deterministic', () {
      final DateTime published = DateTime.utc(2026, 8, 5, 9);
      expect(articleAge(published, now: _now), const HoursAgo(3));
      expect(
        articleAge(published, now: DateTime.utc(2026, 8, 5, 10)),
        const HoursAgo(1),
      );
    });

    test('a local and a UTC timestamp of the same instant agree', () {
      final DateTime utc = DateTime.utc(2026, 8, 5, 9);
      expect(articleAge(utc, now: _now), articleAge(utc.toLocal(), now: _now));
    });
  });
}
