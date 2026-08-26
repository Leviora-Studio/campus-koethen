// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:meta/meta.dart';

/// The submission state of an assignment for the current user.
enum MoodleSubmissionState {
  /// No submission started.
  none,

  /// A draft exists but is not submitted for grading.
  draft,

  /// Submitted for grading.
  submitted,

  /// State could not be determined.
  unknown;

  static MoodleSubmissionState fromRaw(String? raw) {
    switch (raw) {
      case 'new':
      case 'nosubmission':
        return MoodleSubmissionState.none;
      case 'draft':
        return MoodleSubmissionState.draft;
      case 'submitted':
        return MoodleSubmissionState.submitted;
      default:
        return MoodleSubmissionState.unknown;
    }
  }
}

/// The read-only submission status for an assignment.
@immutable
class MoodleSubmissionStatus {
  const MoodleSubmissionStatus({
    this.state = MoodleSubmissionState.unknown,
    this.submittedAt,
    this.isLate = false,
    this.graded = false,
    this.gradeText,
  });

  final MoodleSubmissionState state;
  final DateTime? submittedAt;
  final bool isLate;
  final bool graded;

  /// A short grade label (e.g. "17 / 20"), already reduced to plain text.
  final String? gradeText;

  MoodleSubmissionStatus copyWith({bool? isLate}) => MoodleSubmissionStatus(
    state: state,
    submittedAt: submittedAt,
    isLate: isLate ?? this.isLate,
    graded: graded,
    gradeText: gradeText,
  );

  @override
  bool operator ==(Object other) =>
      other is MoodleSubmissionStatus &&
      other.state == state &&
      other.submittedAt == submittedAt &&
      other.isLate == isLate &&
      other.graded == graded &&
      other.gradeText == gradeText;

  @override
  int get hashCode =>
      Object.hash(state, submittedAt, isLate, graded, gradeText);
}

/// An assignment with its (optional) submission status.
@immutable
class MoodleAssignment {
  const MoodleAssignment({
    required this.id,
    required this.courseId,
    required this.name,
    this.cmid,
    this.intro = '',
    this.dueDate,
    this.cutOffDate,
    this.status,
  });

  final int id;
  final int courseId;
  final String name;

  /// Course module id (for building the web link).
  final int? cmid;

  /// Safe plain text (no HTML/scripts).
  final String intro;

  final DateTime? dueDate;
  final DateTime? cutOffDate;

  /// Loaded on demand via `mod_assign_get_submission_status`.
  final MoodleSubmissionStatus? status;

  MoodleAssignment withStatus(MoodleSubmissionStatus status) =>
      MoodleAssignment(
        id: id,
        courseId: courseId,
        name: name,
        cmid: cmid,
        intro: intro,
        dueDate: dueDate,
        cutOffDate: cutOffDate,
        status: status,
      );

  @override
  bool operator ==(Object other) =>
      other is MoodleAssignment &&
      other.id == id &&
      other.courseId == courseId &&
      other.name == name &&
      other.cmid == cmid &&
      other.intro == intro &&
      other.dueDate == dueDate &&
      other.cutOffDate == cutOffDate &&
      other.status == status;

  @override
  int get hashCode =>
      Object.hash(id, courseId, name, cmid, intro, dueDate, cutOffDate, status);
}
