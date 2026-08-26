// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:meta/meta.dart';

/// A classified failure of the grades feature.
///
/// The categories are deliberately coarse and user-oriented. A [GradeFailure]
/// never carries the credentials, the session, cookies, the `asi` parameter or
/// any HTML response — only the classification travels, so nothing sensitive
/// can leak into a log, an exception or telemetry.
enum GradeFailureKind {
  /// The portal rejected the username/password.
  invalidCredentials,

  /// No network connection.
  networkUnavailable,

  /// The request took too long.
  timeout,

  /// A non-HTTPS URL or a host other than the pinned portal host — refused.
  tlsOrHostRejected,

  /// The portal answered with a server error / is down.
  portalUnavailable,

  /// The expected HTML structure (login form, navigation, grade table) was not
  /// recognised — the portal likely changed.
  portalStructureChanged,

  /// The device secure storage is not available.
  secureStorageUnavailable,

  /// The encrypted local cache could not be opened.
  cacheUnavailable,

  /// The session was lost mid-flow (cookies/asi no longer valid).
  sessionExpired,

  /// Anything not otherwise classified.
  unknown,
}

@immutable
class GradeFailure implements Exception {
  const GradeFailure(this.kind);

  final GradeFailureKind kind;

  @override
  String toString() => 'GradeFailure(${kind.name})';

  @override
  bool operator ==(Object other) => other is GradeFailure && other.kind == kind;

  @override
  int get hashCode => kind.hashCode;
}
