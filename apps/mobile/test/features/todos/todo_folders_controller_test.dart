// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:campus_koethen/features/todos/application/todo_folders_controller.dart';
import 'package:campus_koethen/features/todos/application/todos_controller.dart';
import 'package:campus_koethen/features/todos/domain/todo.dart';
import 'package:campus_koethen/features/todos/domain/todo_folder.dart';
import 'package:campus_koethen/features/todos/domain/todo_store.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

void main() {
  late InMemoryTodoStore store;
  late ProviderContainer container;

  setUp(() {
    store = InMemoryTodoStore();
    container = ProviderContainer(
      overrides: <Override>[todoStoreProvider.overrideWithValue(store)],
    );
    addTearDown(container.dispose);
  });

  Future<List<TodoFolder>> build() =>
      container.read(todoFoldersControllerProvider.future);
  List<TodoFolder> current() =>
      container.read(todoFoldersControllerProvider).requireValue;
  TodoFoldersController controller() =>
      container.read(todoFoldersControllerProvider.notifier);
  TodosController todos() => container.read(todosControllerProvider.notifier);

  test('starts from an empty store', () async {
    expect(await build(), isEmpty);
  });

  test('create appends a trimmed folder and persists it', () async {
    await build();
    await controller().create('  Uni  ');

    expect(current(), hasLength(1));
    expect(current().single.name, 'Uni');
    expect(await store.readFolders(), hasLength(1));
  });

  test('create ignores blank or whitespace-only names', () async {
    await build();
    await controller().create('   ');

    expect(current(), isEmpty);
    expect(await store.readFolders(), isEmpty);
  });

  test('rename replaces the name but ignores blank input', () async {
    await build();
    await controller().create('Alt');
    final String id = current().single.id;

    await controller().rename(id, '  Neu  ');
    expect(current().single.name, 'Neu');

    await controller().rename(id, '   ');
    expect(current().single.name, 'Neu');
  });

  test(
    'delete(moveToUnfiled) removes the folder and clears it from its tasks',
    () async {
      await build();
      await container.read(todosControllerProvider.future);
      await controller().create('Uni');
      final String folderId = current().single.id;
      await todos().add('Aufgabe');
      final String todoId = container
          .read(todosControllerProvider)
          .requireValue
          .single
          .id;
      await todos().moveToFolder(todoId, folderId);

      await controller().delete(folderId, TodoFolderDeleteAction.moveToUnfiled);

      expect(current(), isEmpty);
      final List<Todo> remaining = container
          .read(todosControllerProvider)
          .requireValue;
      expect(remaining, hasLength(1));
      expect(remaining.single.folderId, isNull);
    },
  );

  test(
    'delete(deleteTasks) removes the folder and its tasks, keeps others',
    () async {
      await build();
      await container.read(todosControllerProvider.future);
      await controller().create('Uni');
      final String folderId = current().single.id;
      await todos().add('Im Ordner');
      await todos().add('Woanders');
      final List<Todo> added = container
          .read(todosControllerProvider)
          .requireValue;
      await todos().moveToFolder(added[0].id, folderId);

      await controller().delete(folderId, TodoFolderDeleteAction.deleteTasks);

      expect(current(), isEmpty);
      final List<Todo> remaining = container
          .read(todosControllerProvider)
          .requireValue;
      expect(remaining, hasLength(1));
      expect(remaining.single.title, 'Woanders');
    },
  );
}
