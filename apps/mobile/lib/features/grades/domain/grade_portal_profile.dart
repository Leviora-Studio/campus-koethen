// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'grade_portal.dart';

/// The pinned endpoints of ONE exam portal of Hochschule Anhalt.
///
/// Each implementation is the single source of truth for the ONE host that
/// portal's gateway is allowed to talk to — the two portals deliberately do
/// NOT share an allowlist, so a bug in one profile can never widen the other.
/// Every request is validated against [allows]; anything that is not HTTPS on
/// exactly [host] is refused (`tlsOrHostRejected`).
abstract interface class GradePortalProfile {
  GradePortal get portal;

  String get scheme;

  /// The only host credentials, cookies or session tokens of this portal may
  /// ever reach.
  String get host;

  String get baseUrl;

  /// Public entry page (also the "open in browser" target).
  String get portalUrl;

  /// Form-urlencoded login POST endpoint (fields `asdf` / `fdsa`).
  String get loginUrl;

  /// Logout endpoint, called best-effort in `finally`.
  String get logoutUrl;

  /// True only for an HTTPS URL on exactly [host].
  bool allows(Uri uri);
}

/// The shared host check both portal profiles use.
///
/// It used to be written out per profile as `uri.scheme == scheme &&
/// uri.host == host`, which checks neither the port nor the credentials in
/// the authority. `GremioOrigin.allows` in the requests feature has always
/// checked both and says why; two implementations of one rule in one code
/// base, and the weaker one guarding the exam portals, is the actual finding
/// here (S-10).
///
/// * `userInfo` — `https://evil@service.ssc.hs-anhalt.de/` parses with the
///   expected host and is a classic way to make a URL read as one origin
///   while pointing at another.
/// * a non-default port — `https://service.ssc.hs-anhalt.de:8443/` is the
///   same host and a different service.
///
/// Case-insensitive on the host, because DNS is.
bool gradePortalAllows(
  Uri uri, {
  required String scheme,
  required String host,
}) {
  if (!uri.isAbsolute) return false;
  if (uri.scheme != scheme) return false;
  if (uri.userInfo.isNotEmpty) return false;
  if (uri.host.toLowerCase() != host.toLowerCase()) return false;
  // `Uri.port` returns the scheme's default when none was given, so this
  // accepts an explicit `:443` and rejects everything else.
  return uri.port == Uri.parse('$scheme://$host').port;
}
