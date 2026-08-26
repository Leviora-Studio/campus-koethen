// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which articles the reader has expanded, by slug.
///
/// Kept outside the card because a `ListView` disposes and rebuilds its
/// children as they scroll: state inside the card would collapse an article
/// the moment it left the viewport and came back.
///
/// Not persisted. Whether a card was open is a property of this reading
/// session, not something the app should remember for weeks.
class NewsExpansionController extends Notifier<Set<String>> {
  @override
  Set<String> build() => const <String>{};

  void toggle(String slug) {
    final Set<String> next = state.toSet();
    if (!next.remove(slug)) next.add(slug);
    state = Set<String>.unmodifiable(next);
  }
}

final NotifierProvider<NewsExpansionController, Set<String>>
newsExpansionProvider = NotifierProvider<NewsExpansionController, Set<String>>(
  NewsExpansionController.new,
);

/// A clock that ticks while the feed is on screen.
///
/// One timer for the whole list rather than one per card: "vor 3 min" has to
/// stay honest as the reader scrolls, but sixty cards each running their own
/// timer would keep the device awake for a label.
///
/// A minute is the finest granularity the relative wording distinguishes, so
/// ticking faster would change nothing on screen.
class NewsClock extends Notifier<DateTime> {
  Timer? _timer;

  @override
  DateTime build() {
    _timer = Timer.periodic(
      const Duration(minutes: 1),
      (_) => state = DateTime.now(),
    );
    // Riverpod disposes the notifier when the feed is no longer watched; the
    // timer must not outlive it.
    ref.onDispose(() => _timer?.cancel());
    return DateTime.now();
  }
}

final NotifierProvider<NewsClock, DateTime> newsClockProvider =
    NotifierProvider.autoDispose<NewsClock, DateTime>(NewsClock.new);
