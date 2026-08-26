// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:meta/meta.dart';

/// A course the user is enrolled in.
@immutable
class MoodleCourse {
  const MoodleCourse({
    required this.id,
    required this.fullName,
    this.shortName = '',
    this.summary = '',
    this.startDate,
    this.endDate,
    this.progress,
    this.hidden = false,
  });

  final int id;
  final String fullName;
  final String shortName;

  /// Already reduced to safe plain text (no HTML/scripts).
  final String summary;

  final DateTime? startDate;
  final DateTime? endDate;

  /// Completion progress in percent, if the course reports it.
  final int? progress;

  final bool hidden;

  MoodleCourse copyWith({int? progress}) => MoodleCourse(
    id: id,
    fullName: fullName,
    shortName: shortName,
    summary: summary,
    startDate: startDate,
    endDate: endDate,
    progress: progress ?? this.progress,
    hidden: hidden,
  );

  @override
  bool operator ==(Object other) =>
      other is MoodleCourse &&
      other.id == id &&
      other.fullName == fullName &&
      other.shortName == shortName &&
      other.summary == summary &&
      other.startDate == startDate &&
      other.endDate == endDate &&
      other.progress == progress &&
      other.hidden == hidden;

  @override
  int get hashCode => Object.hash(
    id,
    fullName,
    shortName,
    summary,
    startDate,
    endDate,
    progress,
    hidden,
  );
}
