// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_dimensions.dart';
import '../../../l10n/l10n.dart';
import 'channel_picker_sheet.dart';
import 'tag_filter_list.dart';

/// Opens the one filter the feed has.
///
/// A sheet rather than a screen: the feed gets by with a single button at the
/// top, and the reader keeps the list behind the sheet in view while changing
/// what it shows.
Future<void> showNewsFilterSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (BuildContext context) => const NewsFilterSheet(),
  );
}

/// The contents of the news filter sheet: which channels the feed shows.
class NewsFilterSheet extends ConsumerWidget {
  const NewsFilterSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final TextTheme text = Theme.of(context).textTheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(bottom: AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Semantics(
                header: true,
                child: Text(l10n.newsFilterTitle, style: text.titleLarge),
              ),
            ),
            const TagFilterList(),
            const Flexible(child: ChannelPickerList()),
          ],
        ),
      ),
    );
  }
}
