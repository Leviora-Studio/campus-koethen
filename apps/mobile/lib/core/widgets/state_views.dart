// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:flutter/material.dart';
import "package:campus_koethen/core/theme/app_icons.dart";

import '../../l10n/l10n.dart';
import '../network/api_failure.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';

/// Waiting, in the app's own hand.
///
/// A marker sweeping along a short rule rather than a spinning circle. The
/// reason is not novelty: this app draws every other kind of progress as a line
/// — the rail down the agenda, the bar under the selected tab — and a spinner
/// is the one shape that would have belonged to nothing.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key});

  /// Width of the sweep. Short enough to read as a detail rather than as a
  /// page-wide loading bar, which would look like the screen was broken.
  static const double _sweepWidth = 96;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    return Semantics(
      label: context.l10n.commonLoadingSemanticLabel,
      liveRegion: true,
      excludeSemantics: true,
      // A state view sits wherever the space for it happens to be — often
      // an Expanded region a large keyboard has just shrunk. Scrolling
      // instead of hard-overflowing keeps it merely cramped, never broken.
      child: _CenteredScrollable(
        padding: const EdgeInsets.all(AppSpacing.xxl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            SizedBox(
              width: _sweepWidth,
              child: LinearProgressIndicator(
                minHeight: AppSizes.beam,
                color: colors.accent,
                backgroundColor: colors.surfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              context.l10n.commonLoading,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Nothing here — said properly.
///
/// Bar line, glyph, a headline in the display face and one sentence explaining
/// why. An empty state is the screen a reader sees when something did not work
/// out for them, and it is the last place that should look unfinished.
class EmptyView extends StatelessWidget {
  const EmptyView({
    required this.message,
    this.title,
    this.icon = AppIcons.inbox_outlined,
    this.action,
    super.key,
  });

  final String? title;
  final String message;
  final IconData icon;
  final Widget? action;

  /// The widest the text column may get before it stops being readable.
  static const double _maxWidth = 340;

  @override
  Widget build(BuildContext context) {
    final AppColors colors = context.colors;
    final TextTheme text = Theme.of(context).textTheme;
    // A state view sits wherever the space for it happens to be — often an
    // Expanded region a large keyboard has just shrunk. Scrolling instead of
    // hard-overflowing keeps the action button reachable rather than lost
    // behind a `RenderFlex overflowed` warning.
    return _CenteredScrollable(
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: _maxWidth),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Container(
              width: AppSpacing.xxl,
              height: AppSizes.rule,
              color: colors.rule,
            ),
            const SizedBox(height: AppSpacing.lg),
            Icon(
              icon,
              size: AppSizes.illustrationIcon,
              color: colors.textSecondary,
            ),
            const SizedBox(height: AppSpacing.md),
            // Announced, not merely present. This view usually replaces
            // `LoadingView`, which is itself a live region: without the same
            // treatment the swap is silent, and a screen reader keeps waiting
            // for a load that already failed. The action stays its own node so
            // it remains focusable and pressable.
            Semantics(
              container: true,
              liveRegion: true,
              // A title is optional, so the spoken label must not open with a
              // stray "null. ".
              label: switch (title) {
                final String title => '$title. $message',
                null => message,
              },
              excludeSemantics: true,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  if (title case final String title) ...<Widget>[
                    Text(
                      title,
                      style: text.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  Text(
                    message,
                    style: text.bodyMedium?.copyWith(
                      color: colors.textSecondary,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            if (action != null) ...<Widget>[
              const SizedBox(height: AppSpacing.xl),
              action!,
            ],
          ],
        ),
      ),
    );
  }
}

/// Centers [child] when it fits, scrolls when it does not.
///
/// The plain `Center` these state views used to open with sizes its child
/// with loose constraints, so a [Column] under it always renders at its
/// natural size — larger than the available space is not an option, only an
/// overflow. Giving the scroll view's content a minimum height instead of a
/// fixed one keeps the everyday case (content fits) looking identical, a
/// centered block, while the cramped case (a large keyboard, doubled text)
/// scrolls rather than breaks.
class _CenteredScrollable extends StatelessWidget {
  const _CenteredScrollable({required this.padding, required this.child});

  final EdgeInsets padding;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        // An unbounded parent — a plain scroll ancestor without a
        // `SliverFillRemaining` in between — has no cramped case to guard
        // against, and a minHeight built from an infinite maxHeight is
        // itself an invalid constraint. Fall back to the plain centering
        // this widget used before.
        if (!constraints.maxHeight.isFinite) {
          return Center(
            child: Padding(padding: padding, child: child),
          );
        }
        final double minHeight = (constraints.maxHeight - padding.vertical)
            .clamp(0, double.infinity);
        return SingleChildScrollView(
          padding: padding,
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: minHeight),
            child: Center(child: child),
          ),
        );
      },
    );
  }
}

/// Error state with a retry action.
///
/// The [ApiFailure] is mapped to a localised message; the raw API message is
/// never shown so the UI stays in the user's language.
class ErrorView extends StatelessWidget {
  const ErrorView({required this.onRetry, this.failure, super.key});

  final Object? failure;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return EmptyView(
      icon: AppIcons.error_outline,
      message: messageFor(l10n, failure),
      action: FilledButton.icon(
        onPressed: onRetry,
        icon: const Icon(AppIcons.refresh),
        label: Text(l10n.actionRetry),
      ),
    );
  }

  /// Maps a caught error onto a localised, user-facing message.
  static String messageFor(AppLocalizations l10n, Object? failure) {
    if (failure is! ApiFailure) return l10n.errorGenericMessage;
    return switch (failure.kind) {
      ApiFailureKind.network => l10n.errorNetworkMessage,
      ApiFailureKind.timeout => l10n.errorTimeoutMessage,
      ApiFailureKind.notFound => l10n.errorNotFoundMessage,
      ApiFailureKind.server => l10n.errorServerMessage,
      ApiFailureKind.badRequest => l10n.errorGenericMessage,
      ApiFailureKind.unknown => l10n.errorGenericMessage,
    };
  }
}
