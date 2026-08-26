// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import '../../../core/locale/formatters.dart';
import '../../../l10n/l10n.dart';
import '../domain/article_age.dart';

/// Renders an [ArticleAge] in the reader's language.
///
/// Separate from the classification on purpose: the bucket is a rule and is
/// tested without a BuildContext, the wording is `gen_l10n`.
String newsAgeText(AppLocalizations l10n, String locale, ArticleAge age) =>
    switch (age) {
      JustNow() => l10n.newsAgeJustNow,
      MinutesAgo(:final int minutes) => l10n.newsAgeMinutes(minutes),
      HoursAgo(:final int hours) => l10n.newsAgeHours(hours),
      DaysAgo(:final int days) => l10n.newsAgeDays(days),
      WeeksAgo(:final int weeks) => l10n.newsAgeWeeks(weeks),
      OlderThanWeeks(:final DateTime publishedAt) => AppDateFormats.shortDate(
        publishedAt,
        locale,
      ),
    };
