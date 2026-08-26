// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/hive_todo_store.dart';
import '../domain/todo.dart';
import '../domain/todo_store.dart';

/// Local persistence port for the to-do list. Overridden in tests.
final Provider<TodoStore> todoStoreProvider = Provider<TodoStore>(
  (Ref ref) => HiveTodoStore(),
);

/// Loads and mutates the local to-do list. Every mutation updates the in-memory
/// state first (snappy UI) and then persists the whole list locally.
class TodosController extends AsyncNotifier<List<Todo>> {
  int _seq = 0;

  TodoStore get _store => ref.read(todoStoreProvider);

  @override
  Future<List<Todo>> build() => _store.readAll();

  List<Todo> get _current => state.value ?? const <Todo>[];

  /// True while the stored list could not be read.
  ///
  /// Every mutation below writes the WHOLE list back. With a failed read
  /// `_current` is empty, so adding one task persisted a list of exactly that
  /// task — silently destroying everything that was on the device. A failed
  /// read must therefore block writes entirely until it has been retried.
  bool get _readFailed => state.hasError && !state.hasValue;

  /// Whether a mutation would be carried out at all right now.
  ///
  /// The refusal above protects the stored list, but silence about it is its
  /// own defect: the compose field sits outside the screen body and stays
  /// usable while the body shows the read error, so a task typed there used to
  /// disappear on submit with nothing said. Callers that can be reached in
  /// that state ask first, or read the result of the mutation.
  bool get acceptsWrites => !_readFailed;

  /// Returns false when the write was refused because the list is unreadable.
  Future<bool> _persist(List<Todo> next) async {
    if (_readFailed) return false;
    state = AsyncData<List<Todo>>(next);
    await _store.writeAll(next);
    return true;
  }

  String _newId() => '${DateTime.now().microsecondsSinceEpoch}-${_seq++}';

  /// Adds a new open item at the end. Blank/whitespace-only titles are ignored.
  ///
  /// Returns false when nothing was stored — either the title was blank or the
  /// list could not be read and writing would have destroyed it. The caller
  /// owns the input field and is the only place that can keep the typed text
  /// and say what happened.
  Future<bool> add(String title) async {
    final String trimmed = title.trim();
    if (trimmed.isEmpty) return false;
    final Todo todo = Todo(
      id: _newId(),
      title: trimmed,
      createdAt: DateTime.now(),
    );
    return _persist(<Todo>[..._current, todo]);
  }

  /// Flips the done state of the item with [id].
  Future<void> toggle(String id) async {
    await _persist(<Todo>[
      for (final Todo t in _current)
        if (t.id == id) t.copyWith(done: !t.done) else t,
    ]);
  }

  /// Renames the item with [id]. Blank/whitespace-only titles are ignored.
  Future<void> rename(String id, String title) async {
    final String trimmed = title.trim();
    if (trimmed.isEmpty) return;
    await _persist(<Todo>[
      for (final Todo t in _current)
        if (t.id == id) t.copyWith(title: trimmed) else t,
    ]);
  }

  /// Removes the item with [id].
  Future<void> remove(String id) async {
    await _persist(_current.where((Todo t) => t.id != id).toList());
  }

  /// Removes every completed item.
  Future<void> clearCompleted() async {
    await _persist(_current.where((Todo t) => !t.done).toList());
  }

  /// Puts [todo] back at [index], for the undo action behind a deletion.
  ///
  /// The position matters: appending a restored item at the end would turn
  /// "undo" into "delete and re-add somewhere else", which is not what the
  /// word promises.
  Future<void> restore(Todo todo, {required int index}) async {
    if (_current.any((Todo t) => t.id == todo.id)) return;
    final List<Todo> next = List<Todo>.of(_current);
    next.insert(index.clamp(0, next.length), todo);
    await _persist(next);
  }

  /// Puts several removed items back, each at its own position.
  ///
  /// Restored oldest-index-first so every later insert lands where it was.
  Future<void> restoreAll(List<({Todo todo, int index})> removed) async {
    if (removed.isEmpty) return;
    final List<Todo> next = List<Todo>.of(_current);
    final List<({Todo todo, int index})> ordered =
        List<({Todo todo, int index})>.of(removed)..sort(
          (({Todo todo, int index}) a, ({Todo todo, int index}) b) =>
              a.index.compareTo(b.index),
        );
    for (final ({Todo todo, int index}) item in ordered) {
      if (next.any((Todo t) => t.id == item.todo.id)) continue;
      next.insert(item.index.clamp(0, next.length), item.todo);
    }
    await _persist(next);
  }

  /// Moves the item with [id] into [folderId]. `null` clears the folder — the
  /// item falls back to the default "no folder" area.
  Future<void> moveToFolder(String id, String? folderId) async {
    await _persist(<Todo>[
      for (final Todo t in _current)
        if (t.id == id) t.copyWith(folderId: folderId) else t,
    ]);
  }

  /// Detaches every item currently in [folderId] back to the default area.
  /// Used when a folder is deleted without deleting its tasks.
  Future<void> clearFolder(String folderId) async {
    await _persist(<Todo>[
      for (final Todo t in _current)
        if (t.folderId == folderId) t.copyWith(folderId: null) else t,
    ]);
  }

  /// Removes every item currently in [folderId]. Used when a folder is
  /// deleted together with its tasks.
  Future<void> removeByFolder(String folderId) async {
    await _persist(_current.where((Todo t) => t.folderId != folderId).toList());
  }
}

/// Riverpod 3 auto-retries erroring providers with a backoff timer; that timer
/// outlives widget tests. Disable it — a failed local read just yields empty.
final AsyncNotifierProvider<TodosController, List<Todo>>
todosControllerProvider = AsyncNotifierProvider<TodosController, List<Todo>>(
  TodosController.new,
  retry: (_, _) => null,
);
