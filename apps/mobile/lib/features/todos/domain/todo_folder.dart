// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:meta/meta.dart';

/// One local folder used to organise to-dos. Purely on-device — never sent
/// anywhere. A to-do without a folder lives in the app's default area
/// instead of belonging to one of these.
@immutable
class TodoFolder {
  const TodoFolder({
    required this.id,
    required this.name,
    required this.createdAt,
  });

  final String id;
  final String name;
  final DateTime createdAt;

  TodoFolder copyWith({String? name}) =>
      TodoFolder(id: id, name: name ?? this.name, createdAt: createdAt);

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'name': name,
    'createdAt': createdAt.toIso8601String(),
  };

  static TodoFolder? fromJson(Object? json) {
    if (json is! Map) return null;
    final Object? id = json['id'];
    final Object? name = json['name'];
    if (id is! String || name is! String) return null;
    final DateTime created =
        DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);
    return TodoFolder(id: id, name: name, createdAt: created);
  }

  @override
  bool operator ==(Object other) =>
      other is TodoFolder &&
      other.id == id &&
      other.name == name &&
      other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(id, name, createdAt);
}
