// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:campus_koethen/core/locale/locale_mode.dart';
import 'package:campus_koethen/features/news/domain/article_age.dart';
import 'package:campus_koethen/features/news/presentation/news_age_text.dart';
import 'package:campus_koethen/l10n/l10n.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

Future<AppLocalizations> _l10n(Locale locale) =>
    AppLocalizations.delegate.load(locale);

void main() {
  // DateFormat needs its locale data; the app loads it at start-up.
  setUpAll(() async {
    await initializeDateFormatting('de');
    await initializeDateFormatting('en');
  });

  test('German wording', () async {
    final AppLocalizations de = await _l10n(AppLocales.german);
    String text(ArticleAge age) => newsAgeText(de, 'de', age);

    expect(text(const JustNow()), 'gerade eben');
    expect(text(const MinutesAgo(5)), 'vor 5 min');
    expect(text(const HoursAgo(1)), 'vor 1 h');
    expect(text(const DaysAgo(1)), 'vor 1 Tag');
    expect(text(const DaysAgo(2)), 'vor 2 Tagen');
    expect(text(const WeeksAgo(1)), 'vor 1 Woche');
    expect(text(const WeeksAgo(3)), 'vor 3 Wochen');
  });

  test('English wording', () async {
    final AppLocalizations en = await _l10n(AppLocales.english);
    String text(ArticleAge age) => newsAgeText(en, 'en', age);

    expect(text(const JustNow()), 'just now');
    expect(text(const MinutesAgo(5)), '5 min ago');
    expect(text(const HoursAgo(1)), '1 h ago');
    expect(text(const DaysAgo(1)), '1 day ago');
    expect(text(const DaysAgo(2)), '2 days ago');
    expect(text(const WeeksAgo(1)), '1 week ago');
    expect(text(const WeeksAgo(3)), '3 weeks ago');
  });

  test('an old article shows a date, and it differs per locale', () async {
    final AppLocalizations de = await _l10n(AppLocales.german);
    final AppLocalizations en = await _l10n(AppLocales.english);
    final OlderThanWeeks age = OlderThanWeeks(DateTime.utc(2026, 3, 9, 12));

    final String german = newsAgeText(de, 'de', age);
    final String english = newsAgeText(en, 'en', age);

    expect(german, contains('2026'));
    expect(english, contains('2026'));
    expect(german, isNot(english));
    // Not a relative phrase any more.
    expect(german, isNot(contains('vor')));
  });
}
