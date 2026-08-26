// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:flutter/material.dart';

/// Animation tokens, and the one place that decides whether the app animates.
///
/// "Reduced motion" has **two** sources and either one is enough to switch it
/// on: the operating system's own accessibility setting, and a local toggle in
/// the app. Respecting only the OS would ignore users on a device where they
/// cannot or do not want to change a system-wide setting; respecting only the
/// app toggle would ignore the setting a user already made for every app.
///
/// When reduced motion is active, durations collapse to [Duration.zero] rather
/// than merely getting shorter. A very fast animation is still motion.
@immutable
class AppMotion extends ThemeExtension<AppMotion> {
  const AppMotion({
    required this.reduced,
    required this.fast,
    required this.medium,
    required this.slow,
    required this.curve,
  });

  /// Whether motion is suppressed. Widgets should branch on this rather than
  /// comparing durations to zero.
  final bool reduced;

  /// State changes on a single control (a chip toggling, a ripple settling).
  final Duration fast;

  /// Content changes inside a screen (a list reordering, a card appearing).
  final Duration medium;

  /// Whole-surface transitions (a sheet, a page).
  final Duration slow;

  final Curve curve;

  static const AppMotion enabled = AppMotion(
    reduced: false,
    fast: Duration(milliseconds: 120),
    medium: Duration(milliseconds: 220),
    slow: Duration(milliseconds: 320),
    curve: Curves.easeOutCubic,
  );

  static const AppMotion suppressed = AppMotion(
    reduced: true,
    fast: Duration.zero,
    medium: Duration.zero,
    slow: Duration.zero,
    curve: Curves.linear,
  );

  static AppMotion resolve({
    required bool systemDisablesAnimations,
    required bool userPrefersReducedMotion,
  }) => systemDisablesAnimations || userPrefersReducedMotion
      ? suppressed
      : enabled;

  @override
  AppMotion copyWith({
    bool? reduced,
    Duration? fast,
    Duration? medium,
    Duration? slow,
    Curve? curve,
  }) {
    return AppMotion(
      reduced: reduced ?? this.reduced,
      fast: fast ?? this.fast,
      medium: medium ?? this.medium,
      slow: slow ?? this.slow,
      curve: curve ?? this.curve,
    );
  }

  /// Motion tokens deliberately do **not** interpolate: crossing from animated
  /// to reduced must take effect at once, not fade in over a frame budget.
  @override
  AppMotion lerp(covariant AppMotion? other, double t) =>
      t < 0.5 ? this : (other ?? this);
}

/// Reads [AppMotion] off the theme.
extension AppMotionContext on BuildContext {
  AppMotion get motion =>
      Theme.of(this).extension<AppMotion>() ?? AppMotion.enabled;
}
