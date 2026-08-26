// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:flutter/foundation.dart';

/// A place an application can be addressed to.
///
/// The list comes from the receiving system and is the only source of a valid
/// `locationId`. Nothing here is ever invented locally: an id the app made up
/// would be a 404 at best and somebody else's board at worst.
@immutable
class ApplicationLocation {
  const ApplicationLocation({required this.id, required this.name});

  final int id;
  final String name;

  /// Validated, not trusted (AGENTS.md §4).
  ///
  /// A malformed entry is dropped rather than repaired: a location with no
  /// usable name would appear in the picker as an empty row that silently
  /// routes the application somewhere.
  static ApplicationLocation? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final Object? id = json['id'];
    final Object? name = json['name'];
    if (id is! int) return null;
    if (name is! String || name.trim().isEmpty) return null;
    return ApplicationLocation(id: id, name: name.trim());
  }

  /// Reads a list, keeping whatever is usable.
  ///
  /// One broken entry must not cost the user the whole picker.
  static List<ApplicationLocation> listFrom(Object? json) {
    if (json is! List) return const <ApplicationLocation>[];
    return json
        .map(ApplicationLocation.fromJson)
        .whereType<ApplicationLocation>()
        .toList(growable: false);
  }

  @override
  bool operator ==(Object other) =>
      other is ApplicationLocation && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);
}
