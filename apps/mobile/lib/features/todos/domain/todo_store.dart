// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'todo.dart';
import 'todo_folder.dart';

/// Port: local, on-device persistence for the to-do list and its folders. Each
/// collection is read and written as one unit — both are small and this keeps
/// the store trivially correct.
abstract interface class TodoStore {
  Future<List<Todo>> readAll();
  Future<void> writeAll(List<Todo> todos);

  Future<List<TodoFolder>> readFolders();
  Future<void> writeFolders(List<TodoFolder> folders);
}

/// A volatile in-memory store, used as a safe fallback and in tests.
class InMemoryTodoStore implements TodoStore {
  List<Todo> _items = const <Todo>[];
  List<TodoFolder> _folders = const <TodoFolder>[];

  @override
  Future<List<Todo>> readAll() async => List<Todo>.of(_items);

  @override
  Future<void> writeAll(List<Todo> todos) async =>
      _items = List<Todo>.of(todos);

  @override
  Future<List<TodoFolder>> readFolders() async => List<TodoFolder>.of(_folders);

  @override
  Future<void> writeFolders(List<TodoFolder> folders) async =>
      _folders = List<TodoFolder>.of(folders);
}
