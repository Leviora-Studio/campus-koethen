// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../content/content_block.dart';
import '../links/safe_link_launcher.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import 'remote_image.dart';

/// Renders the block types of the API contract — and nothing else.
///
/// Unknown types never reach this widget: they are dropped server-side and, as
/// a second line of defence, again while parsing (see [ContentBlock.parse]).
class ContentBlocksView extends ConsumerStatefulWidget {
  const ContentBlocksView({required this.blocks, super.key});

  final List<ContentBlock> blocks;

  @override
  ConsumerState<ContentBlocksView> createState() => _ContentBlocksViewState();
}

class _ContentBlocksViewState extends ConsumerState<ContentBlocksView> {
  /// One recognizer per link URL, kept for as long as the blocks are.
  ///
  /// They used to be thrown away and rebuilt at the top of every `build`,
  /// which made a rebuild for an unrelated reason — a theme change, a
  /// snackbar, the list above rebuilding — pay for every link in the article
  /// again. The URLs come from the blocks and only change when those do.
  final Map<String, TapGestureRecognizer> _recognizers =
      <String, TapGestureRecognizer>{};

  @override
  void didUpdateWidget(ContentBlocksView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.blocks, widget.blocks)) _disposeRecognizers();
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final TapGestureRecognizer recognizer in _recognizers.values) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  TapGestureRecognizer _recognizerFor(String url) =>
      _recognizers[url] ??= (TapGestureRecognizer()..onTap = () => _open(url));

  Future<void> _open(String url) async {
    final LinkLaunchResult result = await ref
        .read(linkLauncherProvider)
        .open(url);
    if (!mounted || result == LinkLaunchResult.opened) return;
    final AppLocalizations l10n = context.l10n;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result == LinkLaunchResult.blocked
              ? l10n.errorLinkBlocked
              : l10n.errorLinkNotOpened,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        for (final ContentBlock block in widget.blocks) ...<Widget>[
          _buildBlock(context, block),
          const SizedBox(height: AppSpacing.md),
        ],
      ],
    );
  }

  Widget _buildBlock(BuildContext context, ContentBlock block) {
    final AppColors colors = context.colors;
    final TextTheme text = Theme.of(context).textTheme;

    switch (block) {
      case ParagraphBlock(:final List<InlineNode> children):
        return _inlineText(context, children, text.bodyLarge!);
      case HeadingBlock(:final int level, :final List<InlineNode> children):
        final TextStyle style = switch (level) {
          1 => text.headlineMedium!,
          2 => text.headlineSmall!,
          3 => text.titleLarge!,
          _ => text.titleMedium!,
        };
        return Semantics(
          header: true,
          child: _inlineText(context, children, style),
        );
      case QuoteBlock(:final List<InlineNode> children):
        return DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(color: colors.primary, width: AppSizes.beam),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.md,
              top: AppSpacing.xs,
              bottom: AppSpacing.xs,
            ),
            child: _inlineText(
              context,
              children,
              text.bodyLarge!.copyWith(fontStyle: FontStyle.italic),
            ),
          ),
        );
      case ListBlock(:final bool ordered, :final List<ListItemBlock> items):
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            for (int index = 0; index < items.length; index++)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    SizedBox(
                      width: AppSpacing.xl,
                      child: Text(
                        ordered ? '${index + 1}.' : '•',
                        style: text.bodyLarge?.copyWith(
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                    Expanded(
                      child: _inlineText(
                        context,
                        items[index].children,
                        text.bodyLarge!,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      case ListItemBlock(:final List<InlineNode> children):
        return _inlineText(context, children, text.bodyLarge!);
      case ImageBlock():
        return RemoteImage(
          url: block.url,
          alternativeText: block.alternativeText,
          aspectRatio:
              (block.width != null && block.height != null && block.height! > 0)
              ? block.width! / block.height!
              : null,
        );
    }
  }

  Widget _inlineText(
    BuildContext context,
    List<InlineNode> nodes,
    TextStyle baseStyle,
  ) {
    final AppColors colors = context.colors;
    final List<InlineSpan> spans = <InlineSpan>[];

    for (final InlineNode node in nodes) {
      switch (node) {
        case InlineText():
          spans.add(
            TextSpan(text: node.text, style: _styleFor(node, baseStyle)),
          );
        case InlineLink():
          spans.add(
            TextSpan(
              text: node.text,
              recognizer: _recognizerFor(node.url),
              style: baseStyle.copyWith(
                color: colors.primary,
                decoration: TextDecoration.underline,
                decorationColor: colors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          );
      }
    }

    return Text.rich(TextSpan(children: spans), style: baseStyle);
  }

  TextStyle _styleFor(InlineText node, TextStyle base) {
    return base.copyWith(
      fontWeight: node.bold ? FontWeight.w700 : null,
      fontStyle: node.italic ? FontStyle.italic : null,
      decoration: TextDecoration.combine(<TextDecoration>[
        if (node.underline) TextDecoration.underline,
        if (node.strikethrough) TextDecoration.lineThrough,
      ]),
      fontFamily: node.code ? 'monospace' : null,
    );
  }
}
