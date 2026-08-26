// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:meta/meta.dart';

/// A classified failure of the Moodle feature.
///
/// Only the classification travels — never the token, the password, a full URL
/// with sensitive parameters, a whole Moodle response or any course/assignment
/// content. Nothing sensitive can leak into a log, an exception or telemetry.
enum MoodleFailureKind {
  invalidCredentials,
  tokenRejected,
  tokenExpired,
  networkUnavailable,
  timeout,
  tlsOrHostRejected,
  serviceUnavailable,
  permissionDenied,
  invalidResponse,
  unsupportedModule,
  secureStorageUnavailable,
  cacheUnavailable,
  fileTooLarge,
  downloadFailed,
  unknown,
}

@immutable
class MoodleFailure implements Exception {
  const MoodleFailure(this.kind);

  final MoodleFailureKind kind;

  @override
  String toString() => 'MoodleFailure(${kind.name})';

  @override
  bool operator ==(Object other) =>
      other is MoodleFailure && other.kind == kind;

  @override
  int get hashCode => kind.hashCode;
}
