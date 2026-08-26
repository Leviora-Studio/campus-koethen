// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:flutter/material.dart';
import "package:campus_koethen/core/theme/app_icons.dart";

/// Maps the API's free-form `iconKey` onto a bundled Tabler icon.
///
/// The API may introduce a new key at any time without an app release, so an
/// unknown key must never break a screen: it resolves to [fallback], a neutral
/// icon that carries no wrong meaning.
abstract final class IconKeys {
  /// Neutral icon used for every unknown or missing key.
  static const IconData fallback = AppIcons.label_outline;

  static const Map<String, IconData> _icons = <String, IconData>{
    'campus': AppIcons.school_outlined,
    'news': AppIcons.article_outlined,
    'announcement': AppIcons.campaign_outlined,
    'event': AppIcons.event_outlined,
    'faculty': AppIcons.account_balance_outlined,
    'students-council': AppIcons.groups_outlined,
    'service': AppIcons.support_agent_outlined,
    'library': AppIcons.local_library_outlined,
    'canteen': AppIcons.restaurant_outlined,
    'housing': AppIcons.home_work_outlined,
    'finance': AppIcons.payments_outlined,
    'international': AppIcons.public_outlined,
    'health': AppIcons.health_and_safety_outlined,
    'sports': AppIcons.sports_soccer_outlined,
    'it': AppIcons.devices_outlined,
    'career': AppIcons.work_outline,
  };

  /// Resolves [key] to an icon, falling back to [fallback].
  static IconData resolve(String? key) {
    if (key == null) return fallback;
    return _icons[key.trim().toLowerCase()] ?? fallback;
  }

  /// Whether [key] is a key the app knows. Used by tests.
  static bool isKnown(String? key) =>
      key != null && _icons.containsKey(key.trim().toLowerCase());
}
