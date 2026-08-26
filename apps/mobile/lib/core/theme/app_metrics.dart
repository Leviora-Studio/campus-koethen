// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:flutter/material.dart';

import 'app_dimensions.dart';

/// Spacing and sizing of the app's layout, as one typed token set.
///
/// There is exactly **one** set of values and no runtime choice. The app used
/// to offer a "comfortable" and a "compact" density; neither won, because a
/// preference that only makes the app roomier at the cost of what fits is a
/// question nobody benefits from having to answer.
///
/// The values below are the editorial ones: a wide [screenPadding] so the text
/// column has a real margin, and a [sectionGap] large enough that the bar line
/// opening a section reads as a new movement rather than as another row.
///
/// Screens read these through `context.metrics` rather than reaching for raw
/// constants, so the spacing of the whole app stays one decision instead of a
/// number repeated in fifty widgets.
///
/// [listRowMinHeight] is deliberately pinned to [AppSizes.minTouchTarget]: the
/// tightest the layout may ever get is still a target a finger can hit.
@immutable
class AppMetrics extends ThemeExtension<AppMetrics> {
  const AppMetrics({
    required this.screenPadding,
    required this.cardPadding,
    required this.cardGap,
    required this.sectionGap,
    required this.listRowMinHeight,
    required this.cardRadius,
    required this.timeColumn,
  });

  /// Horizontal padding of a screen's content column.
  final double screenPadding;

  /// Inner padding of a card or panel.
  final double cardPadding;

  /// Vertical gap between two cards in a list.
  final double cardGap;

  /// Vertical gap between two sections of a screen.
  final double sectionGap;

  /// Minimum height of a tappable list row. Never below
  /// [AppSizes.minTouchTarget].
  final double listRowMinHeight;

  final double cardRadius;

  /// Width of the time column that opens every time-based row.
  ///
  /// Shared by the agenda, the week grid and the deadline lists so that a time
  /// sits at the same x-position wherever the app shows one — which is what
  /// makes the bar line between the times and the content read as a single
  /// rail rather than as a per-screen decoration. Wide enough for "08:00"
  /// in the data face at the reader's default text size. It is a *base* width
  /// — read it through [timeColumnFor], never directly, because a fixed column
  /// is the one thing a scaled time cannot live in.
  final double timeColumn;

  /// [timeColumn] grown for the reader's text size.
  ///
  /// The column holds type, and type that has been enlarged needs a wider
  /// column: at roughly 1.6x "08:00" no longer fits in 52 dp and wraps
  /// mid-time, inside the very component whose whole point is that times line
  /// up. The growth is capped at [_maxTimeColumnScale] so a very large text
  /// size still leaves the entry beside it some width to live in — past that
  /// the time wraps onto two lines, which is legible where a clipped one is
  /// not.
  double timeColumnFor(TextScaler scaler) {
    const double sample = 13.5; // AppTypography.data font size.
    final double factor = (scaler.scale(sample) / sample).clamp(
      1.0,
      _maxTimeColumnScale,
    );
    return timeColumn * factor;
  }

  static const double _maxTimeColumnScale = 2;

  /// The one set the app uses.
  static const AppMetrics standard = AppMetrics(
    screenPadding: AppSpacing.gutter,
    cardPadding: AppSpacing.lg,
    cardGap: AppSpacing.md,
    sectionGap: AppSpacing.xl,
    listRowMinHeight: AppSizes.minTouchTarget,
    cardRadius: AppRadius.card,
    timeColumn: 52,
  );

  @override
  AppMetrics copyWith({
    double? screenPadding,
    double? cardPadding,
    double? cardGap,
    double? sectionGap,
    double? listRowMinHeight,
    double? cardRadius,
    double? timeColumn,
  }) {
    return AppMetrics(
      screenPadding: screenPadding ?? this.screenPadding,
      cardPadding: cardPadding ?? this.cardPadding,
      cardGap: cardGap ?? this.cardGap,
      sectionGap: sectionGap ?? this.sectionGap,
      listRowMinHeight: listRowMinHeight ?? this.listRowMinHeight,
      cardRadius: cardRadius ?? this.cardRadius,
      timeColumn: timeColumn ?? this.timeColumn,
    );
  }

  @override
  AppMetrics lerp(covariant AppMetrics? other, double t) {
    if (other == null) return this;
    double mix(double a, double b) => a + (b - a) * t;
    return AppMetrics(
      screenPadding: mix(screenPadding, other.screenPadding),
      cardPadding: mix(cardPadding, other.cardPadding),
      cardGap: mix(cardGap, other.cardGap),
      sectionGap: mix(sectionGap, other.sectionGap),
      listRowMinHeight: mix(listRowMinHeight, other.listRowMinHeight),
      cardRadius: mix(cardRadius, other.cardRadius),
      timeColumn: mix(timeColumn, other.timeColumn),
    );
  }
}

/// Reads [AppMetrics] off the theme.
extension AppMetricsContext on BuildContext {
  AppMetrics get metrics =>
      Theme.of(this).extension<AppMetrics>() ?? AppMetrics.standard;
}
