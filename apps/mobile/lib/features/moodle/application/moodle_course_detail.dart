// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/moodle_repository.dart';
import 'moodle_providers.dart';

/// Loads one course's detail, offline-first.
///
/// On first open it returns the cached bundle if present, otherwise it fetches
/// once (the single permitted on-open network load). A manual refresh forces a
/// fresh fetch via [refreshMoodleCourseDetail].
final moodleCourseDetailProvider =
    FutureProvider.family<MoodleCourseDetail, int>((
      Ref ref,
      int courseId,
    ) async {
      // Drops this bundle the moment the account changes — see
      // `moodleSessionGenerationProvider` for why that is not optional here.
      ref.watch(moodleSessionGenerationProvider);
      final MoodleRepository repo = ref.watch(moodleRepositoryProvider);
      final MoodleCourseDetail? cached = await repo.cachedCourseDetail(
        courseId,
      );
      if (cached != null) return cached;
      return repo.refreshCourseDetail(courseId);
    });

/// Forces a fresh fetch for [courseId], then rebuilds the detail provider so the
/// screen shows the updated bundle.
Future<void> refreshMoodleCourseDetail(WidgetRef ref, int courseId) async {
  await ref.read(moodleRepositoryProvider).refreshCourseDetail(courseId);
  ref.invalidate(moodleCourseDetailProvider(courseId));
}
