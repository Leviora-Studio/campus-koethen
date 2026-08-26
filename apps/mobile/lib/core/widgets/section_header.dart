// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../theme/app_metrics.dart';
import '../theme/app_typography.dart';

/// The small tracked line that names a thing above it.
///
/// Rendered in capitals because that is what makes an eyebrow an eyebrow — but
/// the *string* is never capitalised for anyone but the eye: the original text
/// stays the accessible name, so a screen reader is not handed "MENSA" to
/// spell out one letter at a time.
class Eyebrow extends StatelessWidget {
  const Eyebrow(this.label, {this.color, this.textAlign, super.key});

  final String label;
  final Color? color;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Text(
        label.toUpperCase(),
        textAlign: textAlign,
        style: color == null
            ? context.type.eyebrow
            : context.type.eyebrow.copyWith(color: color),
      ),
    );
  }
}

/// The Taktstrich: a short heavy rule of ink.
///
/// It opens a section the way a bar line opens a measure. Two device pixels of
/// real ink rather than a tinted background — the whole point is that the app's
/// structure is *drawn*, not shaded.
class BarLine extends StatelessWidget {
  const BarLine({this.width = 28, this.color, super.key});

  final double width;
  final Color? color;

  @override
  Widget build(BuildContext context) => Container(
    width: width,
    height: AppSizes.rule,
    color: color ?? context.colors.rule,
  );
}

/// A full-width hairline. The quiet separator between rows of the same kind.
class HairRule extends StatelessWidget {
  const HairRule({this.indent = 0, super.key});

  final double indent;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsetsDirectional.only(start: indent),
    child: Container(height: AppSizes.hairline, color: context.colors.outline),
  );
}

/// A section of a screen: bar line, name, and whatever acts on the section.
///
/// Every list of things in the app is introduced by one of these, which is what
/// keeps a screen readable once it has more than one kind of content on it. The
/// heading is announced as a header so a screen reader can jump between
/// sections.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    required this.label,
    this.trailing,
    this.padding,
    super.key,
  });

  final String label;

  /// The action that belongs to this section — "alle anzeigen", a filter, a
  /// picker. Kept on the heading line so the section owns its own controls.
  final Widget? trailing;

  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final AppMetrics metrics = context.metrics;
    return Padding(
      padding:
          padding ??
          EdgeInsets.fromLTRB(
            metrics.screenPadding,
            metrics.sectionGap,
            metrics.screenPadding,
            AppSpacing.sm,
          ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          BarLine(color: context.colors.primary),
          const SizedBox(height: AppSpacing.sm),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              Expanded(
                child: Semantics(
                  header: true,
                  child: Eyebrow(label, color: context.colors.primary),
                ),
              ),
              if (trailing != null) ...<Widget>[
                const SizedBox(width: AppSpacing.sm),
                trailing!,
              ],
            ],
          ),
        ],
      ),
    );
  }
}
