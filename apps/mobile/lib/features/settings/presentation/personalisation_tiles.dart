// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import "package:campus_koethen/core/theme/app_icons.dart";

import '../../../core/prefs/settings_controller.dart';
import '../../../l10n/l10n.dart';

/// The local reduced-motion switch.
///
/// Its subtitle says outright that the system setting applies anyway, so
/// leaving this off is not mistaken for "animate regardless".
class ReducedMotionTile extends ConsumerWidget {
  const ReducedMotionTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final bool enabled = ref.watch(
      settingsProvider.select((AppSettings s) => s.reducedMotion),
    );

    return SwitchListTile(
      secondary: const Icon(AppIcons.motion_photos_off_outlined),
      title: Text(l10n.settingsReducedMotion),
      subtitle: Text(l10n.settingsReducedMotionSubtitle),
      value: enabled,
      onChanged: (bool value) =>
          ref.read(settingsProvider.notifier).setReducedMotion(value),
    );
  }
}
