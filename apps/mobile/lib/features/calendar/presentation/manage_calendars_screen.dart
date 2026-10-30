// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:flutter/material.dart';

import '../../../core/theme/app_dimensions.dart';
import '../../../l10n/l10n.dart';
import 'event_channel_list.dart';
import '../../../core/widgets/screen_scaffold.dart';
import '../../../app/app_modules.dart';

/// "Kalender verwalten": choose the channels whose events the calendar shows,
/// and open their public calendars in Google Calendar.
///
/// The full-screen form of the same choice the calendar's "Events" sheet
/// offers — both are [EventChannelList], writing the event overview's own
/// source filter, so there is one selection, not three.
/// Reached from the onboarding, where a bottom sheet would be out of place.
class ManageCalendarsScreen extends StatelessWidget {
  const ManageCalendarsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return ScreenScaffold(
      eyebrow: ModuleCategory.study.label(l10n),
      title: l10n.calendarManageTitle,
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              0,
            ),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: Text(
                l10n.calendarSectionPublic,
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
          ),
          const Expanded(child: EventChannelList()),
        ],
      ),
    );
  }
}
