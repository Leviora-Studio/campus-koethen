// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:flutter/material.dart';

/// Central, typed colour tokens of the app.
///
/// This is the **only** place in the code base that is allowed to contain
/// colour literals. Screens and widgets read tokens through
/// `Theme.of(context).extension<AppColors>()` (see [AppColorsContext]).
///
/// ## The three materials of the Campus design
///
/// The design system is built from three materials, and every token below
/// belongs to exactly one of them. Knowing which one a token is answers most
/// questions about where it may be used.
///
/// * **Papier** — the grounds. [background] is the warm, matte canvas;
///   [surface] is the sheet lying on it. Depth is the difference between those
///   two values plus a hairline, never a shadow.
/// * **Tinte** — warm near-black text and rules.
/// * **Beere** — the primary brand colour for actions, links and active state.
/// * **Himmel** — the quiet secondary surface for information and selection.
///
/// ## Light palette — "Papier"
///
/// The light palette is the canonical brand palette of the project. Its ground
/// is a warm off-white rather than pure white: white sheets on a warm canvas
/// separate without a border, and the warmth is what keeps a screen full of
/// black rules from reading as harsh.
///
/// ## Dark palette — "Nachtdruck"
///
/// The dark palette is **not** a mechanical inversion. It keeps the warmth of
/// the light one. Both palettes use the fixed berry brand family and warm,
/// slightly rosy neutrals from the supplied design:
///
/// * `background` and `surface` form a two-step elevation
///   system. Elevation is expressed by lighter surfaces, never by shadows only.
/// * `primary` and `accent` represent the fixed berry brand/active colour.
/// * `surfaceVariant` carries the pale-sky supporting colour family.
/// * `success` and `error` are lightened so that both clear 4.5:1 on
///   `background` and on `surface`.
///
/// Every foreground/background pair the app actually renders is asserted in
/// `test/core/theme/theme_contrast_test.dart` using the WCAG relative
/// luminance formula. See `docs/design/brand.md` for the measured table.
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.brightness,
    required this.primary,
    required this.onPrimary,
    required this.primaryDark,
    required this.primaryContainer,
    required this.onPrimaryContainer,
    required this.accent,
    required this.onAccent,
    required this.background,
    required this.onBackground,
    required this.surface,
    required this.onSurface,
    required this.surfaceVariant,
    required this.onSurfaceVariant,
    required this.outline,
    required this.rule,
    required this.textPrimary,
    required this.textSecondary,
    required this.success,
    required this.onSuccess,
    required this.error,
    required this.onError,
  });

  final Brightness brightness;

  /// Primary brand colour. Carries [onPrimary] when used as a fill.
  final Color primary;
  final Color onPrimary;

  /// Darker brand shade — used for pressed states and strong emphasis.
  final Color primaryDark;

  /// Tinted brand surface. Background only, never a text colour.
  final Color primaryContainer;
  final Color onPrimaryContainer;

  /// Quiet secondary colour. Carries [onAccent].
  final Color accent;
  final Color onAccent;

  /// App scaffold background — "Papier".
  final Color background;
  final Color onBackground;

  /// Cards, sheets, list surfaces — "Blatt".
  final Color surface;
  final Color onSurface;

  /// Slightly raised surface, e.g. chips and inline code-like containers.
  final Color surfaceVariant;
  final Color onSurfaceVariant;

  /// Hairlines and borders. Decorative only — never the sole state carrier.
  final Color outline;

  /// Structural ink: the bar lines, section rules and the "now" marker.
  ///
  /// Separate from [textPrimary] because the two answer different questions. A
  /// rule is a graphical object and only owes 3:1; in the dark palette it is
  /// deliberately a step softer than body ink so a 2 dp bar does not glare.
  final Color rule;

  /// Opacity of the rail beside an entry that is still ahead.
  static const double railAlpha = 0.72;

  /// Opacity of the rail beside an entry that has already happened.
  ///
  /// It used to be 0.32, which put the line at about 2.2:1 — under the 3:1 a
  /// structural rule owes, in the one component that carries the shape of the
  /// day. Raising it keeps "past" quieter than "ahead" without dropping it
  /// below the floor.
  static const double railPastAlpha = 0.5;

  /// The rail as it is actually painted over [ground].
  ///
  /// An alpha pair is something the contrast helper cannot see, so the value
  /// the rail has to clear is asserted against this blend rather than against
  /// the token — which is exactly the gap that let the 0.32 rail through.
  Color railOn(Color ground) =>
      Color.alphaBlend(rule.withValues(alpha: railAlpha), ground);

  /// The past rail as it is actually painted over [ground]. See [railOn].
  Color railPastOn(Color ground) =>
      Color.alphaBlend(rule.withValues(alpha: railPastAlpha), ground);

  /// Body copy on [surface] and [background].
  final Color textPrimary;

  /// Supporting copy on [surface] and [background].
  final Color textSecondary;

  /// Positive state. Always paired with an icon or a text label.
  final Color success;
  final Color onSuccess;

  /// Negative state. Always paired with an icon or a text label.
  final Color error;
  final Color onError;

  /// Canonical light palette from the supplied design system.
  static const AppColors light = AppColors(
    brightness: Brightness.light,
    primary: Color(0xFFC2185B),
    onPrimary: Color(0xFFFDFBFC),
    primaryDark: Color(0xFF97114A),
    primaryContainer: Color(0xFFFBE4EE),
    onPrimaryContainer: Color(0xFF97114A),
    accent: Color(0xFFC2185B),
    onAccent: Color(0xFFFDFBFC),
    background: Color(0xFFFAF7F8),
    onBackground: Color(0xFF221A1E),
    surface: Color(0xFFFDFBFC),
    onSurface: Color(0xFF221A1E),
    surfaceVariant: Color(0xFFE0F2FE),
    onSurfaceVariant: Color(0xFF075985),
    outline: Color(0xFFEADFE4),
    rule: Color(0xFF221A1E),
    textPrimary: Color(0xFF221A1E),
    textSecondary: Color(0xFF6F6268),
    success: Color(0xFF1D7A55),
    onSuccess: Color(0xFFFDFBFC),
    error: Color(0xFFB3261E),
    onError: Color(0xFFFDFBFC),
  );

  /// Canonical dark palette from the supplied design system.
  static const AppColors dark = AppColors(
    brightness: Brightness.dark,
    primary: Color(0xFFEC6E9F),
    onPrimary: Color(0xFF1B1418),
    primaryDark: Color(0xFFF6C6DA),
    primaryContainer: Color(0xFF511F37),
    onPrimaryContainer: Color(0xFFF6C6DA),
    accent: Color(0xFFEC6E9F),
    onAccent: Color(0xFF1B1418),
    background: Color(0xFF1B1418),
    onBackground: Color(0xFFF3ECF0),
    surface: Color(0xFF251D22),
    onSurface: Color(0xFFF3ECF0),
    surfaceVariant: Color(0xFF15384E),
    onSurfaceVariant: Color(0xFF8ECDF2),
    outline: Color(0xFF3A3037),
    rule: Color(0xFFF3ECF0),
    textPrimary: Color(0xFFF3ECF0),
    textSecondary: Color(0xFFA79CA2),
    success: Color(0xFF7CC5A0),
    onSuccess: Color(0xFF1B1418),
    error: Color(0xFFE8837B),
    onError: Color(0xFF1B1418),
  );

  @override
  AppColors copyWith({
    Brightness? brightness,
    Color? primary,
    Color? onPrimary,
    Color? primaryDark,
    Color? primaryContainer,
    Color? onPrimaryContainer,
    Color? accent,
    Color? onAccent,
    Color? background,
    Color? onBackground,
    Color? surface,
    Color? onSurface,
    Color? surfaceVariant,
    Color? onSurfaceVariant,
    Color? outline,
    Color? rule,
    Color? textPrimary,
    Color? textSecondary,
    Color? success,
    Color? onSuccess,
    Color? error,
    Color? onError,
  }) {
    return AppColors(
      brightness: brightness ?? this.brightness,
      primary: primary ?? this.primary,
      onPrimary: onPrimary ?? this.onPrimary,
      primaryDark: primaryDark ?? this.primaryDark,
      primaryContainer: primaryContainer ?? this.primaryContainer,
      onPrimaryContainer: onPrimaryContainer ?? this.onPrimaryContainer,
      accent: accent ?? this.accent,
      onAccent: onAccent ?? this.onAccent,
      background: background ?? this.background,
      onBackground: onBackground ?? this.onBackground,
      surface: surface ?? this.surface,
      onSurface: onSurface ?? this.onSurface,
      surfaceVariant: surfaceVariant ?? this.surfaceVariant,
      onSurfaceVariant: onSurfaceVariant ?? this.onSurfaceVariant,
      outline: outline ?? this.outline,
      rule: rule ?? this.rule,
      textPrimary: textPrimary ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      error: error ?? this.error,
      onError: onError ?? this.onError,
    );
  }

  @override
  AppColors lerp(covariant AppColors? other, double t) {
    if (other == null) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t) ?? a;
    return AppColors(
      brightness: t < 0.5 ? brightness : other.brightness,
      primary: mix(primary, other.primary),
      onPrimary: mix(onPrimary, other.onPrimary),
      primaryDark: mix(primaryDark, other.primaryDark),
      primaryContainer: mix(primaryContainer, other.primaryContainer),
      onPrimaryContainer: mix(onPrimaryContainer, other.onPrimaryContainer),
      accent: mix(accent, other.accent),
      onAccent: mix(onAccent, other.onAccent),
      background: mix(background, other.background),
      onBackground: mix(onBackground, other.onBackground),
      surface: mix(surface, other.surface),
      onSurface: mix(onSurface, other.onSurface),
      surfaceVariant: mix(surfaceVariant, other.surfaceVariant),
      onSurfaceVariant: mix(onSurfaceVariant, other.onSurfaceVariant),
      outline: mix(outline, other.outline),
      rule: mix(rule, other.rule),
      textPrimary: mix(textPrimary, other.textPrimary),
      textSecondary: mix(textSecondary, other.textSecondary),
      success: mix(success, other.success),
      onSuccess: mix(onSuccess, other.onSuccess),
      error: mix(error, other.error),
      onError: mix(onError, other.onError),
    );
  }
}

/// Convenient, null-safe access to [AppColors] from any widget.
extension AppColorsContext on BuildContext {
  AppColors get colors {
    final Brightness brightness = Theme.of(this).brightness;
    return Theme.of(this).extension<AppColors>() ??
        (brightness == Brightness.dark ? AppColors.dark : AppColors.light);
  }
}
