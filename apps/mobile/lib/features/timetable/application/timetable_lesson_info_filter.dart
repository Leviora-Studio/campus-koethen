// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/prefs/preference_keys.dart';
import '../../../core/prefs/settings_controller.dart';
import '../data/timetable_models.dart';
import 'timetable_providers.dart';

/// Per-group exclusions. Exact source strings are keys; no name or group
/// heuristics are applied. A new source string is always visible by default.
class TimetableLessonInfoFilter {
  TimetableLessonInfoFilter({
    required this.groupId,
    Set<String> disabledValues = const <String>{},
    this.hideWithoutInfo = false,
  }) : disabledValues = Set<String>.unmodifiable(disabledValues);

  final String? groupId;
  final Set<String> disabledValues;
  final bool hideWithoutInfo;

  bool accepts(String? value) => value == null || value.trim().isEmpty
      ? !hideWithoutInfo
      : !disabledValues.contains(value);
}

class TimetableLessonInfoFilterController
    extends Notifier<TimetableLessonInfoFilter> {
  @override
  TimetableLessonInfoFilter build() {
    final String? groupId = ref.watch(selectedTimetableGroupIdProvider);
    final store = ref.watch(keyValueStoreProvider);
    return TimetableLessonInfoFilter(
      groupId: groupId,
      disabledValues: groupId == null
          ? const <String>{}
          : (store.getStringList(
                      PreferenceKeys.timetableLessonInfoDisabled(groupId),
                    ) ??
                    const <String>[])
                .toSet(),
      hideWithoutInfo:
          groupId != null &&
          store.getInt(
                PreferenceKeys.timetableLessonInfoWithoutHidden(groupId),
              ) ==
              1,
    );
  }

  Future<void> setSelected(String value, {required bool selected}) async {
    final String? groupId = state.groupId;
    if (groupId == null) return;
    final Set<String> next = <String>{...state.disabledValues};
    if (selected) {
      next.remove(value);
    } else {
      next.add(value);
    }
    state = TimetableLessonInfoFilter(
      groupId: groupId,
      disabledValues: next,
      hideWithoutInfo: state.hideWithoutInfo,
    );
    await ref
        .read(keyValueStoreProvider)
        .setStringList(
          PreferenceKeys.timetableLessonInfoDisabled(groupId),
          next.toList()..sort(),
        );
  }

  Future<void> setWithoutInfoSelected(bool selected) async {
    final String? groupId = state.groupId;
    if (groupId == null) return;
    state = TimetableLessonInfoFilter(
      groupId: groupId,
      disabledValues: state.disabledValues,
      hideWithoutInfo: !selected,
    );
    await ref
        .read(keyValueStoreProvider)
        .setInt(
          PreferenceKeys.timetableLessonInfoWithoutHidden(groupId),
          selected ? 0 : 1,
        );
  }

  Future<void> setAll(
    TimetableLessonInfoOptions options, {
    required bool selected,
  }) async {
    final String? groupId = state.groupId;
    if (groupId == null) return;
    final Set<String> next = <String>{...state.disabledValues};
    if (selected) {
      next.removeAll(options.values);
    } else {
      next.addAll(options.values);
    }
    final bool hideWithoutInfo = options.hasWithoutInfo
        ? !selected
        : state.hideWithoutInfo;
    state = TimetableLessonInfoFilter(
      groupId: groupId,
      disabledValues: next,
      hideWithoutInfo: hideWithoutInfo,
    );
    final store = ref.read(keyValueStoreProvider);
    await store.setStringList(
      PreferenceKeys.timetableLessonInfoDisabled(groupId),
      next.toList()..sort(),
    );
    if (options.hasWithoutInfo) {
      await store.setInt(
        PreferenceKeys.timetableLessonInfoWithoutHidden(groupId),
        hideWithoutInfo ? 1 : 0,
      );
    }
  }
}

final NotifierProvider<
  TimetableLessonInfoFilterController,
  TimetableLessonInfoFilter
>
timetableLessonInfoFilterProvider =
    NotifierProvider<
      TimetableLessonInfoFilterController,
      TimetableLessonInfoFilter
    >(TimetableLessonInfoFilterController.new);
