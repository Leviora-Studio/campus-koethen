// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:flutter/foundation.dart';

/// A topic feedback can be addressed to.
///
/// Comes from `GET /api/public/v1/feedback-areas` and is the only source of a
/// valid `areaId`. Never invented locally and never carried over from an older
/// draft's own category value: those were app-side labels, and reading one as
/// an area id would file the feedback with whichever board happens to hold
/// that number.
@immutable
class FeedbackArea {
  const FeedbackArea({required this.id, required this.name});

  final int id;
  final String name;

  /// Validated, not trusted (AGENTS.md §4).
  ///
  /// A malformed entry is dropped rather than repaired: an area with no usable
  /// name would show up as an empty row that silently routes the feedback.
  static FeedbackArea? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final Object? id = json['id'];
    final Object? name = json['name'];
    if (id is! int) return null;
    if (name is! String || name.trim().isEmpty) return null;
    return FeedbackArea(id: id, name: name.trim());
  }

  /// Reads a list, keeping whatever is usable — one broken entry must not cost
  /// the user the whole picker.
  static List<FeedbackArea> listFrom(Object? json) {
    if (json is! List) return const <FeedbackArea>[];
    return json
        .map(FeedbackArea.fromJson)
        .whereType<FeedbackArea>()
        .toList(growable: false);
  }

  @override
  bool operator ==(Object other) =>
      other is FeedbackArea && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);
}
