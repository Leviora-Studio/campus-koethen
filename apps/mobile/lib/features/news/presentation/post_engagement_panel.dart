// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_icons.dart';
import '../../../l10n/l10n.dart';
import '../application/post_engagement_controller.dart';
import '../data/post_engagement.dart';

class PostEngagementPanel extends ConsumerStatefulWidget {
  const PostEngagementPanel({required this.slug, this.poll, super.key});

  final String slug;
  final PostPoll? poll;

  @override
  ConsumerState<PostEngagementPanel> createState() =>
      _PostEngagementPanelState();
}

class _PostEngagementPanelState extends ConsumerState<PostEngagementPanel> {
  static const _preset = ['👍', '❤️', '🎉', '😂', '😮', '😢'];
  bool _sending = false;

  PostEngagementController? _observing;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = TickerMode.valuesOf(context).enabled;
    if (visible && _observing == null) {
      final controller = ref.read(postEngagementProvider.notifier);
      controller.attach(widget.slug);
      _observing = controller;
    } else if (!visible && _observing != null) {
      _observing?.detach(widget.slug);
      _observing = null;
    }
  }

  @override
  void didUpdateWidget(covariant PostEngagementPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.slug != widget.slug) {
      _observing?.detach(oldWidget.slug);
      _observing?.attach(widget.slug);
    }
  }

  @override
  void dispose() {
    _observing?.detach(widget.slug);
    super.dispose();
  }

  Future<void> _send(
    Future<void> Function(PostEngagementController) write,
  ) async {
    if (_sending) return;
    setState(() => _sending = true);
    try {
      await write(ref.read(postEngagementProvider.notifier));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.postEngagementFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _chooseReaction(String? current) async {
    final emoji = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.postReact,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Wrap(
                spacing: AppSpacing.xs,
                children: [
                  for (final emoji in _preset)
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(emoji),
                      child: Text(
                        emoji,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                  IconButton(
                    tooltip: context.l10n.postAnotherEmoji,
                    icon: const Icon(AppIcons.add),
                    onPressed: () => Navigator.of(context).pop(''),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || emoji == null) return;
    final choice = emoji.isEmpty
        ? await showDialog<String>(
            context: context,
            builder: (_) => const _EmojiDialog(),
          )
        : emoji;
    if (!mounted || choice == null) return;
    await _send(
      (controller) =>
          controller.react(widget.slug, choice == current ? null : choice),
    );
  }

  @override
  Widget build(BuildContext context) {
    final engagement = ref.watch(
      postEngagementProvider.select((state) => state[widget.slug]),
    );
    final poll = widget.poll;
    // Dart AOT can hoist a guarded field read out of the option loop.
    final voteCounts = engagement?.votes ?? const <(String, String), int>{};
    final reactions = engagement?.reactions.entries.toList() ?? [];
    reactions.sort((a, b) => b.value.compareTo(a.value));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (poll != null) ...[
          const SizedBox(height: AppSpacing.md),
          Text(poll.question, style: Theme.of(context).textTheme.titleMedium),
          for (final option in poll.options.entries)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.xs),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _sending
                      ? null
                      : () => _send(
                          (controller) => controller.vote(
                            widget.slug,
                            poll.key,
                            option.key,
                          ),
                        ),
                  child: Row(
                    children: [
                      Icon(
                        engagement?.myVotes[poll.key] == option.key
                            ? AppIcons.radio_button_checked
                            : AppIcons.radio_button_unchecked,
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(child: Text(option.value)),
                      const SizedBox(width: AppSpacing.sm),
                      if (engagement != null)
                        Text('${voteCounts[(poll.key, option.key)] ?? 0}'),
                    ],
                  ),
                ),
              ),
            ),
        ],
        const SizedBox(height: AppSpacing.xs),
        Wrap(
          spacing: AppSpacing.xs,
          runSpacing: AppSpacing.xs,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            for (final reaction in reactions)
              ChoiceChip(
                label: Text('${reaction.key} ${reaction.value}'),
                selected: engagement?.myReaction == reaction.key,
                onSelected: _sending
                    ? null
                    : (selected) => _send(
                        (controller) => controller.react(
                          widget.slug,
                          selected ? reaction.key : null,
                        ),
                      ),
              ),
            Semantics(
              label: context.l10n.postReact,
              button: true,
              enabled: !_sending,
              onTap: _sending
                  ? null
                  : () => _chooseReaction(engagement?.myReaction),
              excludeSemantics: true,
              child: IconButton(
                tooltip: context.l10n.postReact,
                icon: const Icon(AppIcons.add_reaction_outlined),
                onPressed: _sending
                    ? null
                    : () => _chooseReaction(engagement?.myReaction),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _EmojiDialog extends StatefulWidget {
  const _EmojiDialog();

  @override
  State<_EmojiDialog> createState() => _EmojiDialogState();
}

class _EmojiDialogState extends State<_EmojiDialog> {
  String _emoji = '';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AlertDialog(
      title: Text(l10n.postAnotherEmoji),
      content: TextField(
        autofocus: true,
        maxLength: 1,
        decoration: InputDecoration(hintText: l10n.postEmojiHint),
        onChanged: (value) => setState(() => _emoji = value.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.actionClose),
        ),
        FilledButton(
          onPressed: _emoji.characters.length == 1
              ? () => Navigator.of(context).pop(_emoji)
              : null,
          child: Text(l10n.postReact),
        ),
      ],
    );
  }
}
