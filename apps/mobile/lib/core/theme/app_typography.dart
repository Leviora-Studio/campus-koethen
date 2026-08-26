// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:flutter/material.dart';

/// Albert Sans is the single typeface of the supplied design system.
///
/// It is bundled locally (see `pubspec.yaml` and NOTICE.md) and is never
/// fetched at runtime. The aliases keep semantic roles explicit while every
/// role resolves to the same family.
abstract final class AppFonts {
  static const String display = 'AlbertSans';
  static const String ui = 'AlbertSans';
  static const String data = 'AlbertSans';
}

/// The brand type roles that Material's [TextTheme] has no slot for.
///
/// Everything that fits a Material slot lives in the [TextTheme] and is read as
/// `Theme.of(context).textTheme.…`. The three roles below do not fit one, and
/// inventing a use for `displayLarge` to smuggle them in would make the scale
/// unreadable — so they get a typed extension of their own and are read as
/// `context.type.…`.
@immutable
class AppTypography extends ThemeExtension<AppTypography> {
  const AppTypography({
    required this.eyebrow,
    required this.data,
    required this.dataLarge,
    required this.dataSmall,
  });

  /// The small tracked line above a title — the module a screen belongs to,
  /// the name of a section, the category of a card.
  ///
  /// Rendered upper-case by the `Eyebrow` widget, which keeps the original
  /// string as the accessible name so a screen reader is never handed a word
  /// in capitals to spell out letter by letter.
  final TextStyle eyebrow;

  /// Times, room numbers, prices, week numbers — the default data size.
  final TextStyle data;

  /// The one number a row is about: the start time in an agenda row, the price
  /// a meal costs.
  final TextStyle dataLarge;

  /// Data in a tight place — a chip, a grid cell, a caption.
  final TextStyle dataSmall;

  @override
  AppTypography copyWith({
    TextStyle? eyebrow,
    TextStyle? data,
    TextStyle? dataLarge,
    TextStyle? dataSmall,
  }) => AppTypography(
    eyebrow: eyebrow ?? this.eyebrow,
    data: data ?? this.data,
    dataLarge: dataLarge ?? this.dataLarge,
    dataSmall: dataSmall ?? this.dataSmall,
  );

  @override
  AppTypography lerp(covariant AppTypography? other, double t) {
    if (other == null) return this;
    return AppTypography(
      eyebrow: TextStyle.lerp(eyebrow, other.eyebrow, t)!,
      data: TextStyle.lerp(data, other.data, t)!,
      dataLarge: TextStyle.lerp(dataLarge, other.dataLarge, t)!,
      dataSmall: TextStyle.lerp(dataSmall, other.dataSmall, t)!,
    );
  }

  /// Builds the brand roles in the given ink colours.
  static AppTypography of({
    required Color primaryInk,
    required Color secondaryInk,
  }) => AppTypography(
    eyebrow: TextStyle(
      fontFamily: AppFonts.ui,
      fontSize: 12,
      height: 1.2,
      fontWeight: FontWeight.w700,
      letterSpacing: 1.8,
      color: primaryInk,
    ),
    data: TextStyle(
      fontFamily: AppFonts.data,
      fontSize: 13.5,
      height: 1.3,
      fontWeight: FontWeight.w400,
      color: primaryInk,
    ),
    dataLarge: TextStyle(
      fontFamily: AppFonts.data,
      fontSize: 19,
      height: 1.15,
      fontWeight: FontWeight.w700,
      color: primaryInk,
    ),
    dataSmall: TextStyle(
      fontFamily: AppFonts.data,
      fontSize: 12.5,
      height: 1.2,
      fontWeight: FontWeight.w400,
      letterSpacing: 0.2,
      color: secondaryInk,
    ),
  );

  /// Material text scale expressed entirely in Albert Sans.
  static TextTheme textTheme({
    required Color primaryInk,
    required Color secondaryInk,
  }) {
    TextStyle style(
      double size,
      double lineHeight, {
      FontWeight weight = FontWeight.w700,
      double letterSpacing = 0,
      Color? color,
    }) => TextStyle(
      fontFamily: AppFonts.ui,
      fontSize: size,
      height: lineHeight,
      fontWeight: weight,
      letterSpacing: letterSpacing,
      color: color ?? primaryInk,
    );

    return TextTheme(
      displayLarge: style(
        40,
        1.05,
        weight: FontWeight.w800,
        letterSpacing: -0.8,
      ),
      displayMedium: style(
        34,
        1.08,
        weight: FontWeight.w800,
        letterSpacing: -0.68,
      ),
      displaySmall: style(
        29,
        1.12,
        weight: FontWeight.w800,
        letterSpacing: -0.58,
      ),
      headlineLarge: style(
        25,
        1.18,
        weight: FontWeight.w800,
        letterSpacing: -0.4,
      ),
      headlineMedium: style(
        22,
        1.22,
        weight: FontWeight.w700,
        letterSpacing: -0.25,
      ),
      headlineSmall: style(20, 1.28, weight: FontWeight.w700),
      titleLarge: style(19, 1.3, weight: FontWeight.w700),
      titleMedium: style(16, 1.35, weight: FontWeight.w700),
      titleSmall: style(14, 1.4, weight: FontWeight.w700, letterSpacing: 0.1),
      bodyLarge: style(16, 1.55, weight: FontWeight.w400),
      bodyMedium: style(15, 1.5, weight: FontWeight.w400),
      bodySmall: style(
        13.5,
        1.45,
        weight: FontWeight.w400,
        color: secondaryInk,
      ),
      labelLarge: style(15.5, 1.2, weight: FontWeight.w600),
      labelMedium: style(13.5, 1.2, weight: FontWeight.w600),
      labelSmall: style(12, 1.2, weight: FontWeight.w700, letterSpacing: 0.4),
    );
  }
}

/// Reads [AppTypography] off the theme.
extension AppTypographyContext on BuildContext {
  AppTypography get type =>
      Theme.of(this).extension<AppTypography>() ??
      AppTypography.of(
        primaryInk: const Color(0xFF221A1E),
        secondaryInk: const Color(0xFF6F6268),
      );
}
