// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_icons.dart';
import '../../../l10n/l10n.dart';
import '../application/notification_settings_controller.dart';

/// One local time choice shared by onboarding and notification settings.
class DailySummaryTimeTile extends ConsumerWidget {
  const DailySummaryTimeTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final int minutes = ref.watch(
      notificationSettingsProvider.select(
        (preferences) => preferences.dailySummaryMinutes,
      ),
    );
    final TimeOfDay current = TimeOfDay(
      hour: minutes ~/ 60,
      minute: minutes % 60,
    );

    return ListTile(
      leading: const Icon(AppIcons.schedule_outlined),
      title: Text(l10n.notificationsDailySummaryTime),
      subtitle: Text(current.format(context)),
      onTap: () async {
        final TimeOfDay? selected = await showTimePicker(
          context: context,
          initialTime: current,
          helpText: l10n.notificationsDailySummaryTime,
        );
        if (selected == null || !context.mounted) return;
        await ref
            .read(notificationSettingsProvider.notifier)
            .setDailySummaryMinutes(selected.hour * 60 + selected.minute);
      },
    );
  }
}
