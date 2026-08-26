// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:flutter/foundation.dart';

/// The one origin this app is allowed to talk to about applications.
///
/// Every URL the committee system hands back — the status link, the receipt,
/// each document — is **untrusted input from the network**, and each of them
/// carries a secret token. Following one to a host we were not configured for
/// would hand that token to a stranger, which is the whole attack: the server
/// answers with a link, the app fetches it, the token leaves.
///
/// So the allowlist is derived from `REQUESTS_BASE_URL` and from nothing else.
/// It is an **exact** origin match — scheme, host and port — not a suffix test:
/// `gremio.example.attacker.test` ends with the configured host and must still
/// be refused.
@immutable
class GremioOrigin {
  const GremioOrigin._(this.scheme, this.host, this.port);

  final String scheme;
  final String host;
  final int port;

  /// Parses the configured base address.
  ///
  /// Returns `null` for anything that is not usable as an origin: empty, not
  /// absolute, not HTTPS, or carrying credentials. A build configured with
  /// `http://` is not quietly upgraded — it is refused, because the whole
  /// point of this transport is that a student card and a bearer-equivalent
  /// link never travel in the clear.
  static GremioOrigin? parse(String? baseUrl) {
    final String trimmed = (baseUrl ?? '').trim();
    if (trimmed.isEmpty) return null;
    final Uri? uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.isAbsolute) return null;
    if (uri.scheme != 'https') return null;
    if (uri.host.isEmpty) return null;
    if (uri.userInfo.isNotEmpty) return null;
    return GremioOrigin._(uri.scheme, uri.host.toLowerCase(), uri.port);
  }

  /// Whether [url] points at exactly this origin and is safe to fetch.
  ///
  /// Refuses, in this order: unparseable, relative, non-HTTPS, credentials in
  /// the URL, a different host, a different port. Nothing about the *path* is
  /// checked here — the server decides what its own paths mean.
  bool allows(String? url) {
    final String trimmed = (url ?? '').trim();
    if (trimmed.isEmpty) return false;
    final Uri? uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.isAbsolute) return false;
    if (uri.scheme != 'https') return false;
    if (uri.userInfo.isNotEmpty) return false;
    if (uri.host.toLowerCase() != host) return false;
    return uri.port == port;
  }

  /// `https://host` or `https://host:port` when the port is not the default.
  String get value => port == 443 ? 'https://$host' : 'https://$host:$port';

  @override
  bool operator ==(Object other) =>
      other is GremioOrigin &&
      other.scheme == scheme &&
      other.host == host &&
      other.port == port;

  @override
  int get hashCode => Object.hash(scheme, host, port);

  /// The origin only — never a token-bearing path.
  @override
  String toString() => 'GremioOrigin($value)';
}
