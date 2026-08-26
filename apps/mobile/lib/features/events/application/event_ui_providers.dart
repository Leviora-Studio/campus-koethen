// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Which event cards the reader has expanded, by [UnifiedEvent.eventRef].
///
/// Kept outside the card for the same reason as `newsExpansionProvider`: a
/// scrolling list disposes and rebuilds its children, so state inside the
/// card itself would collapse an event the moment it left the viewport.
/// Not persisted — whether a card is open is a property of this reading
/// session, not something the app remembers for weeks.
class EventExpansionController extends Notifier<Set<String>> {
  @override
  Set<String> build() => const <String>{};

  void toggle(String eventRef) {
    final Set<String> next = state.toSet();
    if (!next.remove(eventRef)) next.add(eventRef);
    state = Set<String>.unmodifiable(next);
  }
}

final NotifierProvider<EventExpansionController, Set<String>>
eventExpansionProvider =
    NotifierProvider<EventExpansionController, Set<String>>(
      EventExpansionController.new,
    );
