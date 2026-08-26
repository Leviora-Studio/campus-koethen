// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

/// Outcome of a link launch attempt.
enum LinkLaunchResult {
  /// The OS accepted the request.
  opened,

  /// The URL used a scheme the app refuses to hand to the OS.
  blocked,

  /// The scheme was allowed but the OS could not handle the URL.
  failed,
}

/// Opens external links through safe operating system actions.
///
/// Only `https`, `mailto` and `tel` are ever handed to the platform. Anything
/// else — `http`, `javascript`, `file`, custom app schemes — is refused, even
/// if the API were ever to deliver it.
class SafeLinkLauncher {
  const SafeLinkLauncher();

  static const Set<String> allowedSchemes = <String>{'https', 'mailto', 'tel'};

  /// Returns `true` when [rawUrl] would be handed to the OS.
  static bool isAllowed(String? rawUrl) => _parse(rawUrl) != null;

  Future<LinkLaunchResult> open(String? rawUrl) async {
    final Uri? uri = _parse(rawUrl);
    if (uri == null) return LinkLaunchResult.blocked;
    try {
      final bool launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      return launched ? LinkLaunchResult.opened : LinkLaunchResult.failed;
    } catch (_) {
      return LinkLaunchResult.failed;
    }
  }

  static Uri? _parse(String? rawUrl) {
    if (rawUrl == null) return null;
    final String trimmed = rawUrl.trim();
    if (trimmed.isEmpty) return null;
    final Uri? uri = Uri.tryParse(trimmed);
    if (uri == null) return null;
    if (!allowedSchemes.contains(uri.scheme.toLowerCase())) return null;
    if (uri.scheme.toLowerCase() == 'https' && uri.host.isEmpty) return null;
    return uri;
  }
}

/// Builds a `mailto:` URI from a plain address.
Uri? mailtoUri(String? address) {
  final String? value = address?.trim();
  if (value == null || value.isEmpty || !value.contains('@')) return null;
  return Uri(scheme: 'mailto', path: value);
}

final RegExp _nonDialablePattern = RegExp(r'[^0-9+]');

/// Builds a `tel:` URI from a phone number, keeping only dialable characters.
Uri? telUri(String? number) {
  final String? value = number?.trim();
  if (value == null || value.isEmpty) return null;
  final String dialable = value.replaceAll(_nonDialablePattern, '');
  if (dialable.isEmpty) return null;
  return Uri(scheme: 'tel', path: dialable);
}

final Provider<SafeLinkLauncher> linkLauncherProvider =
    Provider<SafeLinkLauncher>((Ref ref) => const SafeLinkLauncher());
