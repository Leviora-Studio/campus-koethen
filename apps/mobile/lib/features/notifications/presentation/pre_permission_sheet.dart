// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/widgets/sheet_body.dart';
import '../../../l10n/l10n.dart';
import '../application/notification_providers.dart';
import '../application/notification_settings_controller.dart';
import '../domain/notification_category.dart';
import '../domain/notification_permission.dart';
import '../domain/notification_preferences.dart';

/// Runs the opt-in the way LEVIORA-158 specifies it, from wherever the reader
/// showed an interest — the global switch, a bookmarked event, a favourite
/// dish, the timetable group, a Moodle connection.
///
/// The order is the whole point. At contextual entry points the app explains
/// **first**, in its own sheet, and only asks the operating system once the
/// reader has said yes. The final onboarding step is the other explanatory
/// surface and therefore calls the permission controller directly. On iOS the
/// system dialog appears exactly once per installation, so neither path may
/// ask before the benefit is visible (ADR-0001 § 9.8).
///
/// Returns `true` when the reader ends up opted in with a usable permission.
Future<bool> requestNotificationOptIn(
  BuildContext context,
  WidgetRef ref,
) async {
  final NotificationPermissionStatus status = await ref
      .read(notificationPermissionProvider.notifier)
      .currentStatus();

  // Already allowed: nothing to explain and nothing to ask. Every category is
  // on after the opt-in (P2), which is what the empty disabled set means.
  if (status.allowsDelivery) {
    await ref.read(notificationSettingsProvider.notifier).setOptedIn(true);
    return true;
  }

  // Refused before, or switched off in the system settings. Asking again is
  // pointless on iOS and nagging on Android; the settings screen offers the
  // only route that still leads anywhere.
  if (!status.canPrompt) return false;

  if (!context.mounted) return false;
  final bool? proceed = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (BuildContext context) => const _PrePermissionSheet(),
  );

  if (proceed != true) {
    await ref
        .read(notificationSettingsProvider.notifier)
        .markPrePromptDeclined();
    return false;
  }

  final NotificationPermissionStatus granted = await ref
      .read(notificationPermissionProvider.notifier)
      .request();
  if (!granted.allowsDelivery) return false;
  await ref.read(notificationSettingsProvider.notifier).setOptedIn(true);
  return true;
}

/// Offers the opt-in at a **contextual entry point** — the moment somebody
/// bookmarks an event or stars a dish (UX spec § 2.2 A and B).
///
/// Unlike [requestNotificationOptIn], which is a direct answer to somebody
/// reaching for the switch, this one asks only when asking is welcome:
///
/// * not when notifications are already on,
/// * not when the reader has already said "not now" once — one decline is an
///   answer, and repeating the question at every bookmark is how an app
///   teaches people to dismiss it without reading,
/// * not when the operating system has nothing left to ask.
///
/// It is intentionally fire-and-forget from the caller's point of view: an
/// event is saved or a dish is starred either way. The offer is a follow-up,
/// never a gate.
///
/// [category] names what the trigger point would actually deliver — the 11:00
/// hint for a starred dish, the event reminder for a bookmark. It exists for
/// one reason: a reader who switched that category off has answered this
/// question already, and asking it again at the very trigger point they
/// silenced would be the app arguing with its own settings. It changes nothing
/// else — the permission logic stays in [requestNotificationOptIn], and this
/// function does not duplicate a line of it.
Future<void> maybeOfferNotificationOptIn(
  BuildContext context,
  WidgetRef ref, {
  NotificationCategory? category,
}) async {
  final NotificationPreferences preferences = ref.read(
    notificationSettingsProvider,
  );
  if (preferences.optedIn || preferences.prePromptDeclined) return;
  if (category != null && !preferences.isCategoryEnabled(category)) return;
  if (!context.mounted) return;
  await requestNotificationOptIn(context, ref);
}

/// The in-app sheet that prepares the system dialog (UX spec § 2.3).
class _PrePermissionSheet extends StatelessWidget {
  const _PrePermissionSheet();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AppColors colors = context.colors;
    final TextTheme text = Theme.of(context).textTheme;

    return SafeArea(
      child: SheetBody(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.primaryContainer,
                  borderRadius: BorderRadius.circular(AppRadius.badge),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.sm),
                  child: Icon(
                    AppIcons.notifications_active_outlined,
                    color: colors.onPrimaryContainer,
                    size: AppSizes.icon,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              // The initial focus of a sheet belongs on its heading, so a
              // screen reader announces what just opened before anything else.
              Semantics(
                header: true,
                child: Focus(
                  autofocus: true,
                  child: Text(
                    l10n.notificationsPrePromptTitle,
                    style: text.titleLarge?.copyWith(color: colors.textPrimary),
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                l10n.notificationsPrePromptBody,
                style: text.bodyMedium?.copyWith(color: colors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Icon(
                    AppIcons.shield_outlined,
                    size: AppSizes.iconSmall,
                    color: colors.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppSpacing.xs),
                  Expanded(
                    child: Text(
                      l10n.notificationsPrePromptPrivacy,
                      style: text.labelMedium?.copyWith(
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text(l10n.notificationsPrePromptAllow),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text(l10n.notificationsPrePromptNotNow),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
