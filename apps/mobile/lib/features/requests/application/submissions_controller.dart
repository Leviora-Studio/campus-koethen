// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/request_store.dart';
import '../domain/submitted_case.dart';
import 'requests_providers.dart';

/// The cases this device has submitted, newest first.
///
/// Local tracking only. There is no "my submissions" endpoint — the status
/// link *is* the account — so a case that is not in this list is unreachable
/// forever. That is why [add] must succeed before its draft is removed, and
/// why [remove] is a deliberate, warned-about action.
class SubmissionsController extends AsyncNotifier<List<SubmittedCase>> {
  RequestStore get _store => ref.read(requestStoreProvider);

  @override
  Future<List<SubmittedCase>> build() async =>
      _sorted(await _store.readCases());

  static List<SubmittedCase> _sorted(List<SubmittedCase> cases) =>
      cases.toList()..sort(
        (SubmittedCase a, SubmittedCase b) =>
            b.submittedAt.compareTo(a.submittedAt),
      );

  List<SubmittedCase> get _current => state.value ?? const <SubmittedCase>[];

  SubmittedCase? byId(String id) {
    for (final SubmittedCase item in _current) {
      if (item.id == id) return item;
    }
    return null;
  }

  /// Records a case. **Throws** when storage refused it.
  ///
  /// Deliberately not best-effort: the caller is about to delete the draft
  /// that produced this, and a silently dropped write would lose the only way
  /// back to the case.
  Future<void> add(SubmittedCase submitted) async {
    final List<SubmittedCase> next = <SubmittedCase>[
      ..._current.where((SubmittedCase c) => c.id != submitted.id),
      submitted,
    ];
    final List<SubmittedCase> sorted = _sorted(next);
    await _store.writeCases(sorted);
    state = AsyncData<List<SubmittedCase>>(sorted);
  }

  /// Forgets a case locally.
  ///
  /// The status link cannot be recovered — not by the app, not by the
  /// committee, not by e-mail. The UI warns before calling this.
  Future<void> remove(String id) async {
    final List<SubmittedCase> next = _sorted(
      _current.where((SubmittedCase c) => c.id != id).toList(),
    );
    await _store.writeCases(next);
    state = AsyncData<List<SubmittedCase>>(next);
  }

  /// Keeps locally known metadata in step with what the server reports.
  ///
  /// Only the case *number* and title, which are not secret and make the list
  /// readable offline. The status itself is never persisted: the endpoint
  /// answers `no-store`, and a stored status would be presented as current
  /// long after it stopped being true.
  Future<void> noteServerFacts(
    String id, {
    String? number,
    String? title,
  }) async {
    final SubmittedCase? existing = byId(id);
    if (existing == null) return;
    if (existing.number == number && existing.localTitle == title) return;
    final SubmittedCase updated = existing.copyWith(
      number: number ?? existing.number,
      localTitle: (title ?? '').trim().isEmpty ? existing.localTitle : title,
    );
    final List<SubmittedCase> next = _sorted(<SubmittedCase>[
      ..._current.where((SubmittedCase c) => c.id != id),
      updated,
    ]);
    state = AsyncData<List<SubmittedCase>>(next);
    try {
      await _store.writeCases(next);
    } catch (_) {
      // Cosmetic data — a failed write here must not break the screen.
    }
  }
}

final AsyncNotifierProvider<SubmissionsController, List<SubmittedCase>>
submissionsProvider =
    AsyncNotifierProvider<SubmissionsController, List<SubmittedCase>>(
      SubmissionsController.new,
    );
