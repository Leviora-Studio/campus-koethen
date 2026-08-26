// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'grade.dart';
import 'grade_credentials.dart';

/// The single boundary to the HIS-QIS exam portal.
///
/// No Dio, cookie or HTML type appears in this interface, so neither the UI nor
/// the Riverpod controllers ever depend on the transport. The implementation
/// talks ONLY to the pinned portal host, keeps the session in memory, logs out
/// and clears cookies after every call, and maps every raw error to a
/// [GradeFailure] so nothing sensitive escapes.
abstract interface class GradesGateway {
  /// Logs in with [credentials], navigates to the Notenspiegel, parses it, then
  /// logs out and clears the session. Reaching the parsed report also PROVES the
  /// credentials, so callers may store them only after this succeeds.
  ///
  /// Throws [GradeFailure] on any problem. The credentials are used only for the
  /// duration of this call and are never persisted here.
  Future<GradeReport> fetchGrades(GradeCredentials credentials);
}
