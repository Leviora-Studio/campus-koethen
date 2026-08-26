// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:intl/intl.dart';

import '../../../l10n/l10n.dart';
import '../domain/grade.dart';
import '../domain/grade_failure.dart';

/// Maps a [GradeFailure] to a localized, user-safe message. Switches only on the
/// typed kind — no raw portal text, HTML or session detail ever reaches the UI.
String gradeFailureMessage(AppLocalizations l10n, Object? error) {
  if (error is GradeFailure) {
    return switch (error.kind) {
      GradeFailureKind.invalidCredentials => l10n.gradeErrorInvalidCredentials,
      GradeFailureKind.networkUnavailable => l10n.gradeErrorNetwork,
      GradeFailureKind.timeout => l10n.gradeErrorTimeout,
      GradeFailureKind.tlsOrHostRejected => l10n.gradeErrorTls,
      GradeFailureKind.portalUnavailable => l10n.gradeErrorPortalUnavailable,
      GradeFailureKind.portalStructureChanged =>
        l10n.gradeErrorStructureChanged,
      GradeFailureKind.secureStorageUnavailable => l10n.gradeErrorSecureStorage,
      GradeFailureKind.cacheUnavailable => l10n.gradeErrorCache,
      GradeFailureKind.sessionExpired => l10n.gradeErrorSessionExpired,
      GradeFailureKind.unknown => l10n.gradeErrorGeneric,
    };
  }
  return l10n.gradeErrorGeneric;
}

/// The grade shown to the user: a locale-formatted number, "passed (ungraded)"
/// or "no grade".
String gradeText(AppLocalizations l10n, String locale, Grade grade) {
  switch (grade.kind) {
    case GradeKind.graded:
      return NumberFormat.decimalPatternDigits(
        locale: locale,
        decimalDigits: 1,
      ).format(grade.value);
    case GradeKind.passedUngraded:
      return l10n.gradePassedUngraded;
    case GradeKind.none:
      return l10n.gradeNoGrade;
  }
}

/// The status shown to the user; an unknown status keeps its original text.
String statusLabel(AppLocalizations l10n, GradeEntry entry) =>
    switch (entry.status) {
      ExamStatus.passed => l10n.gradeStatusPassed,
      ExamStatus.failed => l10n.gradeStatusFailed,
      ExamStatus.present => l10n.gradeStatusPresent,
      ExamStatus.unknown =>
        entry.statusText.isEmpty ? l10n.gradeStatusPresent : entry.statusText,
    };
