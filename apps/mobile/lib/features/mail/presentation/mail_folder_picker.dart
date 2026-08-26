// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import "package:campus_koethen/core/theme/app_icons.dart";

import '../../../core/theme/app_metrics.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/l10n.dart';
import '../application/mail_folders.dart';
import '../domain/mail_folder.dart';
import 'mail_error_messages.dart';
import 'mail_folder_labels.dart';

/// Opens the folder picker as a modal sheet and switches the selected mailbox.
Future<void> showMailFolderPicker(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (BuildContext _) => const _MailFolderPickerSheet(),
  );
}

class _MailFolderPickerSheet extends ConsumerWidget {
  const _MailFolderPickerSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<List<MailFolder>> folders = ref.watch(mailFoldersProvider);
    final MailFolder selected = ref.watch(selectedMailboxProvider);

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Semantics(
                header: true,
                child: Text(
                  l10n.mailFoldersTitle,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
            Flexible(
              child: folders.when(
                loading: () => const Padding(
                  padding: EdgeInsets.all(AppSpacing.xl),
                  child: LoadingView(),
                ),
                // The provider is not `autoDispose`, so a failed LIST is kept
                // and every reopen of the sheet watches the same error.
                // Without a retry here the folder switch stayed dead until
                // the app was restarted — "just open it again" never worked.
                error: (Object error, _) => Padding(
                  padding: EdgeInsets.all(context.metrics.screenPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      Text(mailFailureMessage(l10n, error)),
                      const SizedBox(height: AppSpacing.md),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: FilledButton.icon(
                          onPressed: () => ref.invalidate(mailFoldersProvider),
                          icon: const Icon(AppIcons.refresh),
                          label: Text(l10n.mailFoldersRetry),
                        ),
                      ),
                    ],
                  ),
                ),
                data: (List<MailFolder> all) {
                  final List<MailFolder> selectable = all
                      .where((MailFolder f) => f.isSelectable)
                      .toList();
                  return ListView.builder(
                    shrinkWrap: true,
                    itemCount: selectable.length,
                    itemBuilder: (BuildContext context, int index) {
                      final MailFolder folder = selectable[index];
                      final bool isCurrent = folder.path == selected.path;
                      return ListTile(
                        leading: Icon(folderIcon(folder.role)),
                        title: Text(folderLabel(l10n, folder)),
                        trailing: isCurrent ? const Icon(AppIcons.check) : null,
                        selected: isCurrent,
                        onTap: () {
                          ref
                              .read(selectedMailboxProvider.notifier)
                              .select(folder);
                          Navigator.of(context).pop();
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
