// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:flutter/material.dart';
import "package:campus_koethen/core/theme/app_icons.dart";

import '../../../core/theme/app_dimensions.dart';
import '../../../core/widgets/sheet_body.dart';
import '../../../l10n/l10n.dart';
import '../application/requests_controller.dart';
import '../domain/application_files.dart';
import '../domain/request_drafts.dart';
import 'request_form_parts.dart';

/// A last look before an application leaves the device.
///
/// An application carries the applicant's name and a copy of their student
/// card, and once it is accepted the draft freezes: there is deliberately no
/// way to correct it afterwards. That makes the moment before sending the only
/// place a mistake can still be caught, and it had no summary at all.
///
/// Returns true when the reader confirms.
Future<bool> showApplicationReviewSheet(
  BuildContext context, {
  required FinanceApplicationDraft draft,
  required String locationName,
}) async {
  final bool? confirmed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (BuildContext context) =>
        _ReviewSheet(draft: draft, locationName: locationName),
  );
  return confirmed ?? false;
}

class _ReviewSheet extends StatelessWidget {
  const _ReviewSheet({required this.draft, required this.locationName});

  final FinanceApplicationDraft draft;
  final String locationName;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final TextTheme text = Theme.of(context).textTheme;
    final List<ApplicationFileSlot> attached = kApplicationSlotOrder
        .where((ApplicationFileSlot s) => draft.fileFor(s) != null)
        .toList();

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        // Scrollable: four attachments plus a long subject at a large text
        // size is more than a sheet's worth of content.
        child: SingleChildScrollView(
          child: SheetBody(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(l10n.requestsReviewTitle, style: text.titleLarge),
                const SizedBox(height: AppSpacing.xs),
                Text(l10n.requestsReviewIntro, style: text.bodySmall),
                const SizedBox(height: AppSpacing.lg),
                _Row(label: l10n.requestsFieldLocation, value: locationName),
                _Row(label: l10n.requestsFieldTitle, value: draft.title),
                _Row(
                  label: l10n.requestsFieldApplicant,
                  value: draft.applicant,
                ),
                const SizedBox(height: AppSpacing.md),
                Text(l10n.requestsReviewFiles, style: text.labelLarge),
                const SizedBox(height: AppSpacing.xs),
                if (attached.isEmpty)
                  Text(l10n.requestsReviewNoFiles, style: text.bodyMedium)
                else
                  for (final ApplicationFileSlot slot in attached)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.xxs),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          const Icon(AppIcons.check, size: AppSizes.iconSmall),
                          const SizedBox(width: AppSpacing.xs),
                          Expanded(
                            child: Text(
                              '${applicationSlotLabel(l10n, slot)}: '
                              '${draft.fileFor(slot)!.fileName}',
                              style: text.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                const SizedBox(height: AppSpacing.xl),
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop(true),
                  icon: const Icon(AppIcons.send_outlined),
                  label: Text(l10n.requestsReviewSend),
                ),
                const SizedBox(height: AppSpacing.xs),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(l10n.requestsReviewBack),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            label,
            style: text.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          Text(value, style: text.bodyMedium),
        ],
      ),
    );
  }
}
