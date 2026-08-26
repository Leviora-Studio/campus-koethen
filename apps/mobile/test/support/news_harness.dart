// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:campus_koethen/features/news/application/news_feed_ui_providers.dart';
import 'package:flutter_riverpod/misc.dart' show Override;

/// The instant every news widget test pretends it is.
final DateTime newsTestNow = DateTime(2026, 8, 5, 12);

/// The feed's clock, stopped.
///
/// In the app the clock ticks once a minute so "vor 3 min" stays honest while
/// the feed is open. A widget test that left that timer running would end with
/// a pending timer — and freezing it is what makes the relative ages assertable
/// in the first place.
class FrozenNewsClock extends NewsClock {
  FrozenNewsClock(this.at);

  final DateTime at;

  @override
  DateTime build() => at;
}

/// Overrides the feed clock with a fixed instant. Use in every news widget test.
Override frozenNewsClock([DateTime? at]) =>
    newsClockProvider.overrideWith(() => FrozenNewsClock(at ?? newsTestNow));
