// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:flutter/material.dart';
import "package:campus_koethen/core/theme/app_icons.dart";

import '../../l10n/l10n.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';

/// Compact, global disclosure for a deployment containing synthetic content.
///
/// The one banner in the app that wears the marker across its full width. That
/// is exactly what the marker is for — this is a live state, it is true of the
/// whole app rather than of one screen, and it has to be impossible to miss or
/// mistake for content. Ink on marker is a 14:1 pairing, so the loudest thing
/// on screen is also the most legible.
class TestEnvironmentNotice extends StatelessWidget {
  const TestEnvironmentNotice({super.key});

  @override
  Widget build(BuildContext context) {
    final String label = context.l10n.testEnvironmentNotice;
    final AppColors colors = context.colors;
    return Semantics(
      container: true,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: colors.accent,
        child: SafeArea(
          bottom: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  AppIcons.science_outlined,
                  size: AppSizes.iconSmall,
                  color: colors.onAccent,
                ),
                const SizedBox(width: AppSpacing.sm),
                Flexible(
                  child: Text(
                    label,
                    style: Theme.of(
                      context,
                    ).textTheme.labelMedium?.copyWith(color: colors.onAccent),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
