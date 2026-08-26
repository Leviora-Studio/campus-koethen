// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import '../domain/gremio_origin.dart';

/// Where applications and feedback are submitted.
///
/// The origin of the student body's committee system, supplied **exclusively**
/// via `--dart-define=REQUESTS_BASE_URL=…`. There is no hard-coded host and no
/// build flavour file: DEV and PROD differ by environment only (AGENTS.md §2,
/// §5).
///
/// The default is deliberately **empty**. A build that was not told where to
/// submit says so instead of guessing an address — an application sent to the
/// wrong place is worse than one that was not sent. A value that is not HTTPS
/// is treated the same way: refused, not silently upgraded.
abstract final class RequestsApiConfig {
  static const String baseUrl = String.fromEnvironment('REQUESTS_BASE_URL');

  /// Versioned prefix of the public API.
  static const String basePath = '/api/public/v1';

  static const String applicationsPath = '$basePath/applications';
  static const String locationsPath = '$basePath/locations';
  static const String feedbackPath = '$basePath/feedback';
  static const String feedbackAreasPath = '$basePath/feedback-areas';
  static const String statusPath = '$basePath/status';

  static const Duration connectTimeout = Duration(seconds: 15);

  /// Generous: the body carries up to four documents.
  static const Duration sendTimeout = Duration(minutes: 2);
  static const Duration receiveTimeout = Duration(seconds: 30);

  /// The parsed origin of this build, or `null` when none is configured.
  ///
  /// Everything the app fetches is checked against this — a link that came
  /// back from the server is untrusted input carrying a secret token, and
  /// following one to another host is how the token leaks.
  static GremioOrigin? get origin => GremioOrigin.parse(baseUrl);

  static bool get isConfigured => origin != null;

  static String stripTrailingSlash(String value) =>
      value.endsWith('/') ? value.substring(0, value.length - 1) : value;
}
