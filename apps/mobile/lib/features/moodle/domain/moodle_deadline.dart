// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:meta/meta.dart';

/// A dated Moodle action item (assignment due, quiz closes, …).
///
/// This is the value the cross-source calendar consumes as its second source.
/// It is produced purely locally from a direct Moodle call and is never mirrored
/// to any Campus-Köthen backend.
@immutable
class MoodleDeadline {
  const MoodleDeadline({
    required this.id,
    required this.title,
    required this.dueAt,
    this.courseId,
    this.courseName,
    this.moduleName,
    this.eventType,
  });

  final int id;
  final String title;

  /// Absolute instant of the deadline (already converted from Unix seconds).
  final DateTime dueAt;

  final int? courseId;
  final String? courseName;

  /// The activity kind, e.g. `assign`, `quiz`.
  final String? moduleName;

  /// The Moodle event type, e.g. `due`, `close`, `open`.
  final String? eventType;

  @override
  bool operator ==(Object other) =>
      other is MoodleDeadline &&
      other.id == id &&
      other.title == title &&
      other.dueAt == dueAt &&
      other.courseId == courseId &&
      other.courseName == courseName &&
      other.moduleName == moduleName &&
      other.eventType == eventType;

  @override
  int get hashCode => Object.hash(
    id,
    title,
    dueAt,
    courseId,
    courseName,
    moduleName,
    eventType,
  );
}
