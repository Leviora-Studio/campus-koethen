// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import "package:campus_koethen/core/theme/app_icons.dart";

import '../../../core/network/loaded.dart';
import '../../../core/prefs/settings_controller.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/widgets/brand_mark.dart';
import '../../../core/widgets/panel.dart';
import '../../../core/widgets/section_header.dart';
import '../../../l10n/l10n.dart';
import '../../calendar/presentation/public_calendar_list.dart';
import '../../campusmap/application/campus_map_providers.dart';
import '../../campusmap/domain/map_catalog.dart';
import '../../canteen/application/canteen_providers.dart';
import '../../canteen/data/canteen_models.dart';
import '../../news/presentation/channel_picker_sheet.dart';
import '../../timetable/application/timetable_providers.dart';
import '../../timetable/data/timetable_models.dart';

/// The steps of the first-run setup, in order.
///
/// Appearance and the navigation bar used to be steps of their own. Both are
/// preferences a student changes when they feel like it, not decisions the app
/// needs before it can be useful — and asking for them up front made the setup
/// twice as long as what it actually had to establish. They live in the
/// settings, where they always did.
enum OnboardingStep { welcome, campus, content, notifications }

/// Renders one step.
class OnboardingStepView extends StatelessWidget {
  const OnboardingStepView({
    required this.step,
    required this.notificationsEnabled,
    required this.onNotificationsEnabledChanged,
    super.key,
  });

  final OnboardingStep step;
  final bool notificationsEnabled;
  final ValueChanged<bool> onNotificationsEnabledChanged;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return switch (step) {
      OnboardingStep.welcome => _StepScaffold(
        title: l10n.onboardingWelcomeTitle,
        body: l10n.onboardingWelcomeBody,
        // The first screen of the app is the one place the mark introduces
        // itself, so it stands in for the step's glyph rather than beside it.
        lead: const BrandWordmark(),
        children: <Widget>[
          // The independence notice is part of the very first thing a user
          // sees. It is a project rule, not a footnote.
          Panel(
            child: Text(
              l10n.aboutIndependenceNotice,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        ],
      ),
      OnboardingStep.campus => _StepScaffold(
        title: l10n.onboardingCampusTitle,
        body: l10n.onboardingCampusBody,
        icon: AppIcons.place_outlined,
        children: const <Widget>[
          _CanteenStep(),
          _DefaultBuildingStep(),
          _TimetableGroupStep(),
        ],
      ),
      OnboardingStep.content => _StepScaffold(
        title: l10n.onboardingContentTitle,
        body: l10n.onboardingContentBody,
        icon: AppIcons.rss_feed_outlined,
        children: const <Widget>[_ContentPickers()],
      ),
      OnboardingStep.notifications => _StepScaffold(
        title: l10n.onboardingNotificationsTitle,
        body: l10n.onboardingNotificationsBody,
        icon: AppIcons.notifications_active_outlined,
        children: <Widget>[
          _NotificationStep(
            enabled: notificationsEnabled,
            onChanged: onNotificationsEnabledChanged,
          ),
        ],
      ),
    };
  }
}

class _StepScaffold extends StatelessWidget {
  const _StepScaffold({
    required this.title,
    required this.body,
    required this.children,
    this.icon,
    this.lead,
  });

  final String title;
  final String body;

  /// The step's glyph. Ignored when [lead] is given.
  final IconData? icon;

  /// Something to open the step with instead of a glyph.
  final Widget? lead;

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final TextTheme text = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      children: <Widget>[
        if (lead != null)
          lead!
        else ...<Widget>[
          const BarLine(),
          const SizedBox(height: AppSpacing.md),
          Icon(
            icon,
            size: AppSizes.illustrationIcon,
            color: context.colors.textPrimary,
          ),
        ],
        const SizedBox(height: AppSpacing.lg),
        Semantics(
          header: true,
          // headlineSmall, not a display size: a huge heading eats the content
          // it introduces on a 320 px phone.
          child: Text(title, style: text.headlineSmall),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(body, style: text.bodyMedium),
        const SizedBox(height: AppSpacing.lg),
        ...children,
      ],
    );
  }
}

/// Preferred canteen. An empty or failing catalogue is stated, never blocking.
class _CanteenStep extends ConsumerWidget {
  const _CanteenStep();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<Loaded<List<Canteen>>> canteens = ref.watch(
      canteensProvider,
    );
    final String? chosen = ref.watch(
      settingsProvider.select((AppSettings s) => s.preferredCanteenSlug),
    );

    return switch (canteens) {
      AsyncError<Loaded<List<Canteen>>>() => _Unavailable(
        label: l10n.settingsPreferredCanteen,
        onRetry: () => ref.invalidate(canteensProvider),
      ),
      AsyncData<Loaded<List<Canteen>>>(:final Loaded<List<Canteen>> value)
          when value.value.isEmpty =>
        _Unavailable(
          label: l10n.settingsPreferredCanteen,
          message: l10n.onboardingNoCanteens,
        ),
      AsyncData<Loaded<List<Canteen>>>(:final Loaded<List<Canteen>> value) =>
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _StepLabel(l10n.settingsPreferredCanteen),
            RadioGroup<String>(
              groupValue: chosen,
              onChanged: (String? slug) =>
                  ref.read(settingsProvider.notifier).setPreferredCanteen(slug),
              child: Column(
                children: <Widget>[
                  for (final Canteen canteen in value.value)
                    RadioListTile<String>.adaptive(
                      value: canteen.slug,
                      title: Text(canteen.displayName),
                    ),
                ],
              ),
            ),
          ],
        ),
      _ => const _StepLoading(),
    };
  }
}

/// Default building for the campus map.
class _DefaultBuildingStep extends ConsumerWidget {
  const _DefaultBuildingStep();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<MapCatalog> catalog = ref.watch(mapCatalogProvider);
    final MapCatalog? map = catalog.value;
    final String? chosen = ref.watch(
      settingsProvider.select((AppSettings s) => s.defaultBuildingKey),
    );
    // `value == null` covers loading AND failure, so this step announced "not
    // available" while the catalogue was still being read — the two neighbour
    // steps get this right and show a spinner (ONB-1).
    if (map == null && catalog.isLoading) return const _StepLoading();
    if (map == null || map.buildings.isEmpty) {
      return _Unavailable(
        label: l10n.settingsDefaultBuilding,
        onRetry: () => ref.invalidate(mapCatalogProvider),
      );
    }
    final String locale = Localizations.localeOf(context).languageCode;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _StepLabel(l10n.settingsDefaultBuilding),
        RadioGroup<String>(
          groupValue: chosen,
          onChanged: (String? key) =>
              ref.read(settingsProvider.notifier).setDefaultBuilding(key),
          child: Column(
            children: <Widget>[
              for (final MapBuilding building in map.buildings)
                RadioListTile<String>.adaptive(
                  value: building.buildingKey,
                  title: Text(building.name.resolve(locale)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// The timetable group — the same shape as the canteen and the building above.
///
/// A row that opened a separate picker made this one choice look different
/// from the two beside it, for no reason a reader could see. The list can be
/// long, so it is capped and searchable in the settings; here it simply
/// scrolls with the rest of the step.
class _TimetableGroupStep extends ConsumerWidget {
  const _TimetableGroupStep();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<Loaded<List<TimetableGroup>>> groups = ref.watch(
      timetableGroupsProvider,
    );
    final String? chosen = ref.watch(selectedTimetableGroupIdProvider);

    return switch (groups) {
      AsyncError<Loaded<List<TimetableGroup>>>() => _Unavailable(
        label: l10n.settingsTimetableGroup,
      ),
      AsyncData<Loaded<List<TimetableGroup>>>(
        :final Loaded<List<TimetableGroup>> value,
      )
          when value.value.isEmpty =>
        _Unavailable(
          label: l10n.settingsTimetableGroup,
          message: l10n.timetableNoGroupsMessage,
        ),
      AsyncData<Loaded<List<TimetableGroup>>>(
        :final Loaded<List<TimetableGroup>> value,
      ) =>
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            _StepLabel(l10n.settingsTimetableGroup),
            RadioGroup<String>(
              groupValue: chosen,
              onChanged: (String? id) =>
                  ref.read(settingsProvider.notifier).setTimetableGroup(id),
              child: Column(
                children: <Widget>[
                  for (final TimetableGroup group in value.value)
                    RadioListTile<String>.adaptive(
                      value: group.id,
                      title: Text(group.shortName),
                      // Long name and department, verbatim from the source —
                      // exactly what the settings picker shows.
                      subtitle: _groupSubtitle(group),
                    ),
                ],
              ),
            ),
          ],
        ),
      _ => const _StepLoading(),
    };
  }
}

/// News channels and public calendars, picked **inside** the setup.
///
/// These used to be rows that pushed the settings screens. That could not
/// work: while the setup is unfinished the router sends every other route
/// straight back to it, so tapping either row bounced the reader to step one
/// with everything they had answered still saved but out of sight.
///
/// The pickers themselves are reused unchanged — both already handle their own
/// loading, empty and offline states, and a second copy of those rules would
/// drift from the original the first time one of them changed.
class _ContentPickers extends StatelessWidget {
  const _ContentPickers();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _StepLabel(l10n.onboardingOpenChannels),
        const ChannelPickerList(),
        const SizedBox(height: AppSpacing.lg),
        _StepLabel(l10n.onboardingOpenCalendars),
        const PublicCalendarList(shrinkWrap: true),
      ],
    );
  }
}

/// Introduces every notification category before the operating system asks.
///
/// This step is the app-owned explanation, so continuing from it can open the
/// system dialog directly instead of stacking the separate pre-permission
/// sheet on top. The switch is only a pending onboarding choice; the actual
/// opt-in is stored after the platform grants delivery.
class _NotificationStep extends StatelessWidget {
  const _NotificationStep({required this.enabled, required this.onChanged});

  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final TextTheme text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Panel(
          child: Column(
            children: <Widget>[
              _NotificationFeature(
                icon: AppIcons.today_outlined,
                text: l10n.onboardingNotificationsDailySummary,
              ),
              const SizedBox(height: AppSpacing.md),
              _NotificationFeature(
                icon: AppIcons.calendar_month_outlined,
                text: l10n.onboardingNotificationsEvents,
              ),
              const SizedBox(height: AppSpacing.md),
              _NotificationFeature(
                icon: AppIcons.restaurant_outlined,
                text: l10n.onboardingNotificationsCanteen,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Semantics(
          label: l10n.onboardingNotificationsEnable,
          value: enabled
              ? l10n.notificationsSwitchStateOn
              : l10n.notificationsSwitchStateOff,
          hint: enabled
              ? l10n.notificationsSwitchHintDisable
              : l10n.notificationsSwitchHintEnable,
          child: SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            secondary: const Icon(AppIcons.notifications_outlined),
            title: Text(l10n.onboardingNotificationsEnable),
            subtitle: Text(l10n.onboardingNotificationsEnableHint),
            value: enabled,
            onChanged: onChanged,
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Icon(
              AppIcons.shield_outlined,
              size: AppSizes.iconSmall,
              color: context.colors.textSecondary,
            ),
            const SizedBox(width: AppSpacing.xs),
            Expanded(
              child: Text(
                l10n.onboardingNotificationsPrivacy,
                style: text.bodySmall?.copyWith(
                  color: context.colors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _NotificationFeature extends StatelessWidget {
  const _NotificationFeature({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[
      Icon(icon, size: AppSizes.iconSmall, color: context.colors.textSecondary),
      const SizedBox(width: AppSpacing.sm),
      Expanded(child: Text(text)),
    ],
  );
}

/// Long name and department of a timetable group, both verbatim.
Widget? _groupSubtitle(TimetableGroup group) {
  final List<String> parts = <String?>[
    group.longName,
    group.department,
  ].whereType<String>().toList(growable: false);
  if (parts.isEmpty) return null;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: <Widget>[for (final String part in parts) Text(part)],
  );
}

class _StepLabel extends StatelessWidget {
  const _StepLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: AppSpacing.xs),
    child: Text(text, style: Theme.of(context).textTheme.titleSmall),
  );
}

class _StepLoading extends StatelessWidget {
  const _StepLoading();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
    child: Center(child: CircularProgressIndicator()),
  );
}

/// A source that cannot be offered right now. Says so and stays out of the way.
class _Unavailable extends StatelessWidget {
  const _Unavailable({required this.label, this.message, this.onRetry});

  final String label;
  final String? message;

  /// Offered where the source can simply be asked again.
  ///
  /// Onboarding runs exactly once, so a source that happened to be
  /// unreachable in that minute silently cost the reader a setting with no
  /// way to try again and no hint that it can be picked later (ONB-2).
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final ColorScheme colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _StepLabel(label),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Icon(
                AppIcons.info_outline,
                size: AppSizes.iconSmall,
                color: colors.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      message ?? context.l10n.onboardingSourceUnavailable,
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      context.l10n.onboardingChooseLaterHint,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (onRetry != null)
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(AppIcons.refresh, size: AppSizes.iconSmall),
                label: Text(context.l10n.actionRetry),
              ),
            ),
        ],
      ),
    );
  }
}
