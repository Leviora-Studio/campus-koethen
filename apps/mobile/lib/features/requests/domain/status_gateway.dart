// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'case_status.dart';

/// What came back from asking for a case's current state.
sealed class StatusResult {
  const StatusResult();
}

/// The current state, as the endpoint reports it.
///
/// Held in memory only: the endpoint answers `Cache-Control: no-store`, and
/// keeping it on disk would let the app present a stale state as current.
class StatusLoaded extends StatusResult {
  const StatusLoaded(this.status);

  final CaseStatus status;
}

/// No endpoint is configured in this build.
class StatusNotConnected extends StatusResult {
  const StatusNotConnected();
}

/// The stored link is malformed or not one this instance accepts (400).
///
/// **Never a reason to delete the local record.** The link is the only way
/// back to the case; throwing it away on one bad answer would strand a case
/// that a later build, or a fixed server, could still reach.
class StatusLinkInvalid extends StatusResult {
  const StatusLinkInvalid();
}

/// The case was not found (404).
///
/// Also not a reason to delete: the endpoint answers this identically for an
/// unknown token, a deleted case and a token of the wrong type.
class StatusNotFound extends StatusResult {
  const StatusNotFound();
}

/// Rate limited (429). [retryAfter] is the server's own instruction and is
/// honoured rather than guessed around.
class StatusRateLimited extends StatusResult {
  const StatusRateLimited({this.retryAfter});

  final Duration? retryAfter;
}

/// Temporarily unavailable: no network, timeout, 5xx, or a body that could not
/// be read. Retryable, and never presented as "the case is gone".
class StatusUnavailable extends StatusResult {
  const StatusUnavailable(this.reason);

  /// A short technical reason. Never carries the status link.
  final String reason;
}

/// Port: reads the public state of one case.
///
/// The link travels in the JSON body of a POST, never in a query parameter —
/// it is a bearer credential, and a query string ends up in proxy logs,
/// browser history and monitoring. The call carries no idempotency key: it
/// changes nothing and may be repeated freely.
abstract interface class StatusGateway {
  Future<StatusResult> fetch(String statusUrl);
}

/// Used when no endpoint is configured for this build.
class NotConnectedStatusGateway implements StatusGateway {
  const NotConnectedStatusGateway();

  @override
  Future<StatusResult> fetch(String statusUrl) =>
      Future<StatusResult>.value(const StatusNotConnected());
}
