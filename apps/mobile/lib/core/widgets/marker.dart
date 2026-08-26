// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

/// Compact brand and active-state indicators.
///
/// These widgets keep badges, beams and highlighted text visually consistent
/// with the fixed berry palette. Every active state also has a textual or
/// structural cue and never relies on colour alone.
library;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_typography.dart';

/// A short heavy active-state beam.
///
/// The selected tab wears one above its glyph — above rather than below so it
/// keeps its place when a large text size drops the labels — and the agenda
/// draws one across the rail at the current time. Purely decorative on its own:
/// every caller pairs it with a word or a glyph, because a state is never
/// carried by colour alone.
class MarkerBeam extends StatelessWidget {
  const MarkerBeam({
    this.width = 24,
    this.height = AppSizes.beam,
    this.alignment = Alignment.center,
    super.key,
  });

  final double width;
  final double height;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) => Align(
    alignment: alignment,
    child: Container(
      width: width,
      height: height,
      color: context.colors.accent,
    ),
  );
}

/// A word with a highlighter stroke behind it.
///
/// The stroke is a real fill and the text on it is `onAccent`, which is a
/// 14:1 pairing in both palettes — so this is the one place the marker may sit
/// directly under type.
class MarkerText extends StatelessWidget {
  const MarkerText(this.label, {this.style, super.key});

  final String label;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.primaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.xxs,
        ),
        child: Text(
          label,
          style: (style ?? Theme.of(context).textTheme.labelMedium)?.copyWith(
            color: colors.onPrimaryContainer,
          ),
        ),
      ),
    );
  }
}

/// A count or a one-word state, set in the data face on a marker field.
///
/// Used for unread mail, for "heute" on a date and for the number of entries a
/// day carries. [semanticLabel] is what a screen reader hears, because "3" on
/// its own is not information.
class MarkerBadge extends StatelessWidget {
  const MarkerBadge({
    required this.label,
    required this.semanticLabel,
    this.quiet = false,
    super.key,
  });

  final String label;
  final String semanticLabel;

  /// Draws the badge in ink instead of marker.
  ///
  /// For counts that are merely present rather than live — a folder's total,
  /// say. Keeps the shape so the two read as one family.
  final bool quiet;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    return Semantics(
      label: semanticLabel,
      excludeSemantics: true,
      child: Container(
        constraints: const BoxConstraints(minWidth: AppSpacing.xl),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.xxs,
        ),
        decoration: BoxDecoration(
          color: quiet ? colors.surfaceVariant : colors.accent,
          borderRadius: BorderRadius.circular(AppRadius.card / 2),
          border: quiet
              ? Border.all(color: colors.outline, width: AppSizes.hairline)
              : null,
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: context.type.dataSmall.copyWith(
            color: quiet ? colors.textSecondary : colors.onAccent,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}
