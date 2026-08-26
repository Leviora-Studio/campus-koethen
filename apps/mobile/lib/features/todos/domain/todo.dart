// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:meta/meta.dart';

/// One local to-do item. Purely on-device — never sent anywhere.
@immutable
class Todo {
  const Todo({
    required this.id,
    required this.title,
    required this.createdAt,
    this.done = false,
    this.folderId,
  });

  final String id;
  final String title;
  final bool done;
  final DateTime createdAt;

  /// The folder this item belongs to, or `null` for the default "no folder"
  /// area. Absent in data written before folders existed — that data reads
  /// back as `null`, which is exactly the default area, so no migration step
  /// is needed.
  final String? folderId;

  static const Object _unset = Object();

  /// [folderId] defaults to "leave unchanged"; pass an explicit `null` to
  /// move the item back to the default area.
  Todo copyWith({String? title, bool? done, Object? folderId = _unset}) => Todo(
    id: id,
    title: title ?? this.title,
    done: done ?? this.done,
    createdAt: createdAt,
    folderId: identical(folderId, _unset) ? this.folderId : folderId as String?,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'title': title,
    'done': done,
    'createdAt': createdAt.toIso8601String(),
    'folderId': folderId,
  };

  static Todo? fromJson(Object? json) {
    if (json is! Map) return null;
    final Object? id = json['id'];
    final Object? title = json['title'];
    if (id is! String || title is! String) return null;
    final DateTime created =
        DateTime.tryParse(json['createdAt']?.toString() ?? '') ??
        DateTime.fromMillisecondsSinceEpoch(0);
    final Object? folderId = json['folderId'];
    return Todo(
      id: id,
      title: title,
      done: json['done'] == true,
      createdAt: created,
      folderId: folderId is String ? folderId : null,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Todo &&
      other.id == id &&
      other.title == title &&
      other.done == done &&
      other.createdAt == createdAt &&
      other.folderId == folderId;

  @override
  int get hashCode => Object.hash(id, title, done, createdAt, folderId);
}
