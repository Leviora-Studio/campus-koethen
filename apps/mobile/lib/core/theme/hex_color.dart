// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'dart:ui';

/// Tolerantly parses a CMS hex colour (`#RRGGBB` or `#AARRGGBB`).
///
/// Returns null on anything malformed so the caller can fall back to a design
/// token — a bad CMS value must never crash a screen, and the colour is only
/// ever used as a decorative accent, never as the sole carrier of state.
final RegExp _hexPattern = RegExp(r'^[0-9A-Fa-f]+$');

Color? parseHexColor(String? value) {
  if (value == null) return null;
  final String hex = value.trim().replaceFirst('#', '');
  if (hex.length != 6 && hex.length != 8) return null;
  if (!_hexPattern.hasMatch(hex)) return null;
  final String argb = hex.length == 6 ? 'FF$hex' : hex;
  final int? parsed = int.tryParse(argb, radix: 16);
  return parsed == null ? null : Color(parsed);
}

/// The ARGB int of a parsed hex colour, or null when malformed.
int? parseHexColorArgb(String? value) => parseHexColor(value)?.toARGB32();
