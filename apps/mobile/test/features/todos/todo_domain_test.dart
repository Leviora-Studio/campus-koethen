// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:campus_koethen/features/todos/domain/todo.dart';
import 'package:campus_koethen/features/todos/domain/todo_folder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Todo', () {
    test('round-trips through JSON including the folder id', () {
      final Todo todo = Todo(
        id: '1',
        title: 'Einkaufen',
        createdAt: DateTime(2026, 1, 1),
        folderId: 'folder-1',
      );
      final Todo? restored = Todo.fromJson(todo.toJson());
      expect(restored, todo);
    });

    test('data written before folders existed decodes with folderId null — '
        'the default "no folder" area, with no data loss', () {
      final Todo? restored = Todo.fromJson(<String, dynamic>{
        'id': '1',
        'title': 'Alte Aufgabe',
        'done': true,
        'createdAt': DateTime(2026, 1, 1).toIso8601String(),
      });
      expect(restored, isNotNull);
      expect(restored!.folderId, isNull);
      expect(restored.title, 'Alte Aufgabe');
      expect(restored.done, isTrue);
    });

    test('copyWith leaves folderId untouched by default', () {
      final Todo todo = Todo(
        id: '1',
        title: 'A',
        createdAt: DateTime(2026),
        folderId: 'folder-1',
      );
      expect(todo.copyWith(title: 'B').folderId, 'folder-1');
    });

    test('copyWith(folderId: null) explicitly clears the folder', () {
      final Todo todo = Todo(
        id: '1',
        title: 'A',
        createdAt: DateTime(2026),
        folderId: 'folder-1',
      );
      expect(todo.copyWith(folderId: null).folderId, isNull);
    });
  });

  group('TodoFolder', () {
    test('round-trips through JSON', () {
      final TodoFolder folder = TodoFolder(
        id: 'f1',
        name: 'Uni',
        createdAt: DateTime(2026, 1, 1),
      );
      expect(TodoFolder.fromJson(folder.toJson()), folder);
    });

    test('fromJson rejects malformed input', () {
      expect(TodoFolder.fromJson(<String, dynamic>{'id': 'f1'}), isNull);
      expect(TodoFolder.fromJson('not a map'), isNull);
    });

    test('copyWith renames without touching id or createdAt', () {
      final TodoFolder folder = TodoFolder(
        id: 'f1',
        name: 'Uni',
        createdAt: DateTime(2026, 1, 1),
      );
      final TodoFolder renamed = folder.copyWith(name: 'Studium');
      expect(renamed.id, folder.id);
      expect(renamed.createdAt, folder.createdAt);
      expect(renamed.name, 'Studium');
    });
  });
}
