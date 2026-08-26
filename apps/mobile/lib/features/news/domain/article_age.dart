// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:meta/meta.dart';

/// How old an article is, as a bucket rather than a formatted string.
///
/// The bucket is the decision; the wording belongs to `gen_l10n`. Keeping them
/// apart is what makes the rule testable without a BuildContext and without
/// asserting on German text.
@immutable
sealed class ArticleAge {
  const ArticleAge();
}

/// Under a minute — and everything in the future.
class JustNow extends ArticleAge {
  const JustNow();
  @override
  bool operator ==(Object other) => other is JustNow;
  @override
  int get hashCode => 0;
}

class MinutesAgo extends ArticleAge {
  const MinutesAgo(this.minutes);
  final int minutes;
  @override
  bool operator ==(Object other) =>
      other is MinutesAgo && other.minutes == minutes;
  @override
  int get hashCode => Object.hash('m', minutes);
}

class HoursAgo extends ArticleAge {
  const HoursAgo(this.hours);
  final int hours;
  @override
  bool operator ==(Object other) => other is HoursAgo && other.hours == hours;
  @override
  int get hashCode => Object.hash('h', hours);
}

class DaysAgo extends ArticleAge {
  const DaysAgo(this.days);
  final int days;
  @override
  bool operator ==(Object other) => other is DaysAgo && other.days == days;
  @override
  int get hashCode => Object.hash('d', days);
}

class WeeksAgo extends ArticleAge {
  const WeeksAgo(this.weeks);
  final int weeks;
  @override
  bool operator ==(Object other) => other is WeeksAgo && other.weeks == weeks;
  @override
  int get hashCode => Object.hash('w', weeks);
}

/// Old enough that "vor 14 Wochen" says less than the date itself.
class OlderThanWeeks extends ArticleAge {
  const OlderThanWeeks(this.publishedAt);
  final DateTime publishedAt;
  @override
  bool operator ==(Object other) =>
      other is OlderThanWeeks && other.publishedAt == publishedAt;
  @override
  int get hashCode => publishedAt.hashCode;
}

/// Beyond this the relative form stops helping and a short date is shown.
const Duration kRelativeAgeLimit = Duration(days: 28);

/// Classifies an article's age against [now].
///
/// Returns `null` when there is no timestamp: an article without a publication
/// date gets **no** date invented for it.
///
/// A timestamp in the future is treated as [JustNow] rather than as a negative
/// age. Clocks disagree, and a card reading "in 3 hours" would look broken for
/// something the reader can see right now.
ArticleAge? articleAge(DateTime? publishedAt, {required DateTime now}) {
  if (publishedAt == null) return null;

  final Duration elapsed = now.difference(publishedAt);
  if (elapsed.isNegative || elapsed.inMinutes < 1) return const JustNow();
  if (elapsed.inHours < 1) return MinutesAgo(elapsed.inMinutes);
  if (elapsed.inDays < 1) return HoursAgo(elapsed.inHours);
  if (elapsed.inDays < 7) return DaysAgo(elapsed.inDays);
  if (elapsed < kRelativeAgeLimit) return WeeksAgo(elapsed.inDays ~/ 7);
  return OlderThanWeeks(publishedAt);
}
