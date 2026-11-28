// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'json.dart';

class CampusLocation {
  const CampusLocation({required this.slug, required this.name});

  final String slug;
  final String name;

  static CampusLocation? fromJson(Object? json) {
    final map = asJsonMap(json);
    final slug = asString(map?['slug']);
    final name = asString(map?['name']);
    if (slug == null || name == null) return null;
    return CampusLocation(slug: slug, name: name);
  }

  Map<String, String> toJson() => {'slug': slug, 'name': name};
}
