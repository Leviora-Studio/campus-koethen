// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

/// Categories of failures the UI needs to distinguish.
///
/// Deliberately coarse: the UI maps each kind onto one localised message. The
/// API's `error.message` is never rendered raw, because the app must stay
/// translated even when the API replies in the other locale.
enum ApiFailureKind { network, timeout, notFound, badRequest, server, unknown }

/// A transport or contract level failure of a Campus API call.
class ApiFailure implements Exception {
  const ApiFailure({required this.kind, this.code, this.statusCode});

  final ApiFailureKind kind;

  /// Machine readable code from the API error envelope, e.g.
  /// `NEWS_ARTICLE_NOT_FOUND`. Never shown to users.
  final String? code;

  final int? statusCode;

  @override
  String toString() =>
      'ApiFailure(kind: $kind, code: $code, statusCode: $statusCode)';
}
