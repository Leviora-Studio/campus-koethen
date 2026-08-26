// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

/// The rail: how this app draws time.
///
/// Every list of things that happen — the day's agenda, a week's deadlines, a
/// course's submissions — is set the same way:
///
/// ```
///  08:00 ┃ Mathematik II
///  09:30 ┃ Hörsaal 3 · Vorlesung
///        ┃
///  09:45 ┃ Praktikum Physik
/// ```
///
/// A mono time column, then a continuous ink rail, then the entry. Two things
/// follow from that, and both are the reason it exists rather than a stack of
/// cards:
///
/// * **Times line up.** The column is [AppMetrics.timeColumn] wide everywhere
///   in the app and the face is monospaced, so a reader scans down a straight
///   edge of numbers instead of hunting for each one inside a card.
/// * **Gaps are visible.** The rail is continuous, so an empty hour is an empty
///   stretch of line. A list of cards makes a free afternoon look exactly like
///   a full one.
///
/// The rail is drawn as the leading border of each row rather than as one long
/// line behind them: rows then join seamlessly however many there are, and the
/// list stays a plain `ListView` that builds only what is on screen.
library;

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_metrics.dart';
import '../theme/app_typography.dart';

/// How a row relates to the present moment.
enum TimeRailEmphasis {
  /// An ordinary entry.
  normal,

  /// Happening right now. The rail turns to marker for the length of the row.
  now,

  /// Already over. Set in secondary ink so the day reads as a progress bar.
  past,
}

/// One entry on the rail.
class TimeRailTile extends StatelessWidget {
  const TimeRailTile({
    required this.child,
    this.start,
    this.end,
    this.emphasis = TimeRailEmphasis.normal,
    this.tint,
    this.onTap,
    this.trailing,
    this.semanticLabel,
    super.key,
  });

  /// Start of the entry, already formatted — "08:00".
  final String? start;

  /// End of the entry. Sits under the start in the smaller data size.
  final String? end;

  final TimeRailEmphasis emphasis;

  /// The colour of the source this entry came from, as a dot on the rail.
  ///
  /// Decorative only: every caller also names the source in the row, because a
  /// coloured dot is not a label.
  final Color? tint;

  final VoidCallback? onTap;
  final Widget? trailing;

  /// What a screen reader announces instead of the row's loose strings.
  final String? semanticLabel;

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final AppMetrics metrics = context.metrics;
    final AppTypography type = context.type;
    final bool isNow = emphasis == TimeRailEmphasis.now;
    final bool isPast = emphasis == TimeRailEmphasis.past;

    final Color railColour = isNow
        ? colors.accent
        : colors.rule.withValues(
            alpha: isPast ? AppColors.railPastAlpha : AppColors.railAlpha,
          );
    final Color timeColour = isPast ? colors.textSecondary : colors.textPrimary;

    final Widget row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        SizedBox(
          width: metrics.timeColumnFor(MediaQuery.textScalerOf(context)),
          child: Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (start != null)
                  Text(
                    start!,
                    style: type.data.copyWith(
                      color: timeColour,
                      fontWeight: isNow ? FontWeight.w700 : null,
                    ),
                  ),
                if (end != null)
                  Text(
                    end!,
                    style: type.dataSmall.copyWith(color: colors.textSecondary),
                  ),
              ],
            ),
          ),
        ),
        Expanded(
          child: Container(
            constraints: BoxConstraints(minHeight: metrics.listRowMinHeight),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: railColour,
                  // The live row carries the heaviest stroke in the system, so
                  // "now" is legible as a weight as well as a colour.
                  width: isNow ? AppSizes.beam : AppSizes.rule,
                ),
              ),
            ),
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.md,
              AppSpacing.md,
              0,
              AppSpacing.md,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                if (tint != null)
                  Padding(
                    padding: const EdgeInsets.only(
                      top: AppSpacing.xs,
                      right: AppSpacing.sm,
                    ),
                    child: Container(
                      width: AppSpacing.sm,
                      height: AppSpacing.sm,
                      decoration: BoxDecoration(
                        color: tint,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                Expanded(child: child),
                if (trailing != null) ...<Widget>[
                  const SizedBox(width: AppSpacing.sm),
                  trailing!,
                ],
              ],
            ),
          ),
        ),
      ],
    );

    Widget tile = row;
    if (onTap != null) {
      tile = Material(
        color: Colors.transparent,
        child: InkWell(onTap: onTap, child: row),
      );
    }
    if (semanticLabel != null) {
      tile = Semantics(
        label: semanticLabel,
        button: onTap != null,
        excludeSemantics: true,
        child: tile,
      );
    }
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: metrics.screenPadding),
      child: tile,
    );
  }
}

/// The present moment, drawn across the rail.
///
/// A marker beam with the current time beside it, inserted between the entry
/// that has finished and the one that has not started. It is the app's single
/// loudest graphic, and it earns that: on a day screen the one thing a reader
/// wants before anything else is *where am I*.
class NowRule extends StatelessWidget {
  const NowRule({required this.time, required this.semanticLabel, super.key});

  /// The current time, already formatted.
  final String time;

  /// "Gerade jetzt, 10:42" — never just the number.
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final AppMetrics metrics = context.metrics;

    return Semantics(
      label: semanticLabel,
      liveRegion: true,
      excludeSemantics: true,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: metrics.screenPadding,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          children: <Widget>[
            SizedBox(
              width: metrics.timeColumnFor(MediaQuery.textScalerOf(context)),
              child: Text(
                time,
                style: context.type.data.copyWith(
                  color: colors.textPrimary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Expanded(
              child: Container(height: AppSizes.beam, color: colors.accent),
            ),
          ],
        ),
      ),
    );
  }
}

/// A stretch of rail with nothing on it.
///
/// Used where a list would otherwise close up over an empty day: the line keeps
/// running, which is what says "nothing here" rather than "nothing left".
class RailGap extends StatelessWidget {
  const RailGap({this.height = AppSpacing.xl, this.label, super.key});

  final double height;

  /// Optional word in the gap — "keine Termine".
  final String? label;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final AppMetrics metrics = context.metrics;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: metrics.screenPadding),
      // The explicit height is what lets the row stretch its children: a
      // stretched cross axis needs a bounded one, and inside a list it is not.
      child: SizedBox(
        height: height,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SizedBox(
              width: metrics.timeColumnFor(MediaQuery.textScalerOf(context)),
            ),
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  border: Border(
                    left: BorderSide(
                      color: colors.rule.withValues(
                        alpha: AppColors.railPastAlpha,
                      ),
                      width: AppSizes.rule,
                    ),
                  ),
                ),
                padding: const EdgeInsets.only(left: AppSpacing.md),
                alignment: AlignmentDirectional.centerStart,
                child: label == null
                    ? null
                    : Text(
                        label!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
