// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/locale/locale_providers.dart';
import '../../../core/network/loaded.dart';
import '../../../core/prefs/settings_controller.dart';
import '../data/timetable_models.dart';
import '../data/timetable_repository.dart';
import 'timetable_week.dart';

/// All selectable study groups. Comes exclusively from the Campus API.
final FutureProvider<Loaded<List<TimetableGroup>>> timetableGroupsProvider =
    FutureProvider<Loaded<List<TimetableGroup>>>((Ref ref) async {
      final String locale = ref.watch(localeCodeProvider);
      return ref.watch(timetableRepositoryProvider).fetchGroups(locale: locale);
    });

/// The group the user chose, or `null` when they have not chosen yet.
///
/// There is deliberately **no** automatic default: a wrong timetable is worse
/// than none, so the screen shows an onboarding state instead.
final Provider<String?> selectedTimetableGroupIdProvider = Provider<String?>(
  (Ref ref) => ref.watch(
    settingsProvider.select(
      (AppSettings settings) => settings.timetableGroupId,
    ),
  ),
);

/// The day the timetable screen currently shows. Defaults to today.
///
/// The visible week is derived from this single value, so week navigation and
/// day selection can never drift apart.
class SelectedTimetableDayController extends Notifier<DateTime> {
  @override
  DateTime build() => TimetableWeek.dayOf(DateTime.now());

  void select(DateTime date) => state = TimetableWeek.dayOf(date);

  void today() => select(DateTime.now());

  void previousWeek() =>
      state = TimetableWeek.shift(state, -TimetableWeek.lengthInDays);

  void nextWeek() =>
      state = TimetableWeek.shift(state, TimetableWeek.lengthInDays);
}

final NotifierProvider<SelectedTimetableDayController, DateTime>
selectedTimetableDayProvider =
    NotifierProvider<SelectedTimetableDayController, DateTime>(
      SelectedTimetableDayController.new,
    );

/// One timetable request: a group and a calendar week.
///
/// A value type, so the provider family keeps one independent entry per group
/// and per week instead of overwriting a single one.
@immutable
class TimetableWeekRequest {
  TimetableWeekRequest({required this.groupId, required DateTime weekStart})
    : weekStart = TimetableWeek.startOf(weekStart);

  final String groupId;
  final DateTime weekStart;

  DateTime get weekEnd =>
      TimetableWeek.shift(weekStart, TimetableWeek.lengthInDays - 1);

  @override
  bool operator ==(Object other) =>
      other is TimetableWeekRequest &&
      other.groupId == groupId &&
      other.weekStart == weekStart;

  @override
  int get hashCode => Object.hash(groupId, weekStart);

  @override
  String toString() => 'TimetableWeekRequest($groupId, $weekStart)';
}

/// The timetable of one group for one week.
final timetableWeekProvider =
    FutureProvider.family<Loaded<Timetable>, TimetableWeekRequest>((
      Ref ref,
      TimetableWeekRequest request,
    ) async {
      final String locale = ref.watch(localeCodeProvider);
      return ref
          .watch(timetableRepositoryProvider)
          .fetchEntries(
            locale: locale,
            groupId: request.groupId,
            from: request.weekStart,
            to: request.weekEnd,
          );
    });
