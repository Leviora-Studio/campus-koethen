// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

/// The pinned Moodle endpoints of Hochschule Anhalt.
///
/// The single source of truth for the ONE host the token and personal data may
/// ever reach. Every request is validated with [allows]; anything that is not
/// HTTPS on exactly [host] is refused, and the token is only ever sent there.
class MoodleProfile {
  const MoodleProfile();

  String get scheme => 'https';

  /// The only host the Moodle token may be sent to.
  String get host => 'moodle.hs-anhalt.de';

  String get baseUrl => 'https://moodle.hs-anhalt.de';

  /// `POST` form-urlencoded token endpoint (`username`, `password`, `service`).
  String get tokenUrl => 'https://moodle.hs-anhalt.de/login/token.php';

  /// `POST` REST endpoint (`wstoken`, `wsfunction`, `moodlewsrestformat=json`).
  String get restUrl =>
      'https://moodle.hs-anhalt.de/webservice/rest/server.php';

  /// The mobile web service the token is issued for.
  String get service => 'moodle_mobile_app';

  /// "Open in browser" target.
  String get webUrl => 'https://moodle.hs-anhalt.de';

  /// True only for the exact HTTPS origin represented by [baseUrl].
  ///
  /// A hostname check alone is not enough for token-bearing requests: a
  /// different service can listen on a non-default port of the same host, and
  /// user-info must never be accepted as part of a credential-bearing URL.
  bool allows(Uri uri) =>
      uri.isAbsolute &&
      uri.scheme == scheme &&
      uri.host.toLowerCase() == host &&
      uri.port == 443 &&
      uri.userInfo.isEmpty;
}
