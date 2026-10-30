// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import "package:campus_koethen/core/theme/app_icons.dart";

import '../../../core/links/safe_link_launcher.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/hex_color.dart';
import '../../../l10n/l10n.dart';
import '../../events/application/event_providers.dart';
import '../../events/application/event_source_filter.dart';
import '../../news/application/news_providers.dart';
import '../../news/data/news_models.dart';
import '../application/public_calendar_providers.dart';
import '../domain/public_calendar.dart';

/// The channels whose events the calendar shows, each with its own switch and
/// — when the channel has a public Google calendar — the way into it.
///
/// The choice is the event overview's own source filter, not a second one:
/// switching a channel off here hides its events in the Events tab too. Two
/// selections for the same events would leave the reader no way to tell why an
/// event shows up in one place and not in the other.
class EventChannelList extends ConsumerWidget {
  const EventChannelList({this.shrinkWrap = false, super.key});

  /// Set inside a bottom sheet, where the list sizes itself to its content.
  final bool shrinkWrap;

  Future<void> _open(BuildContext context, WidgetRef ref, String url) async {
    final AppLocalizations l10n = context.l10n;
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);
    final LinkLaunchResult result = await ref
        .read(linkLauncherProvider)
        .open(url);
    if (result != LinkLaunchResult.opened) {
      messenger.showSnackBar(
        SnackBar(content: Text(l10n.calendarGoogleLinkFailed)),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<List<EventSourceOption>> options = ref.watch(
      eventSourceOptionsProvider,
    );
    final EventSourceFilterState filter = ref.watch(eventSourceFilterProvider);
    final Map<String, NewsChannel> channels = <String, NewsChannel>{
      for (final NewsChannel channel
          in ref.watch(newsChannelsProvider).value?.value ??
              const <NewsChannel>[])
        channel.slug: channel,
    };
    // Optional: without the catalogue the channels can still be chosen, they
    // only lack their Google link until it arrives.
    final Map<String, PublicCalendar> calendarByChannel =
        <String, PublicCalendar>{
          for (final PublicCalendar calendar
              in ref.watch(publicCalendarsCatalogProvider).value?.value ??
                  const <PublicCalendar>[])
            if (calendar.channelSlug case final String channel)
              channel: calendar,
        };

    return options.when(
      loading: () => const Padding(
        padding: EdgeInsets.all(AppSpacing.xl),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, _) => Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: Text(
          l10n.calendarPublicUnavailable,
          textAlign: TextAlign.center,
        ),
      ),
      data: (List<EventSourceOption> options) {
        if (options.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Text(
              l10n.calendarNoPublicCalendars,
              textAlign: TextAlign.center,
            ),
          );
        }
        return ListView.builder(
          shrinkWrap: shrinkWrap,
          physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
          itemCount: options.length + 1,
          itemBuilder: (BuildContext context, int index) {
            if (index == 0) {
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.sm,
                ),
                child: Text(
                  l10n.calendarEventChannelsShared,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              );
            }
            final EventSourceOption option = options[index - 1];
            final PublicCalendar? calendar = calendarByChannel[option.key];
            return EventChannelTile(
              label: option.label,
              colorHex: channels[option.key]?.colorHex,
              selected: filter.isSelected(option.key),
              dataStale: calendar?.dataStale ?? false,
              onChanged: (bool value) => ref
                  .read(eventSourceFilterProvider.notifier)
                  .setSelected(option.key, selected: value),
              onOpenInGoogle: calendar == null
                  ? null
                  : () => _open(context, ref, calendar.googleOpenUrl),
            );
          },
        );
      },
    );
  }
}

/// One channel: its name, its colour as decoration only, a switch and — when
/// it has a public calendar — the safe link into Google Calendar.
class EventChannelTile extends StatelessWidget {
  const EventChannelTile({
    required this.label,
    required this.selected,
    required this.onChanged,
    this.colorHex,
    this.dataStale = false,
    this.onOpenInGoogle,
    super.key,
  });

  final String label;
  final String? colorHex;
  final bool selected;
  final bool dataStale;
  final ValueChanged<bool> onChanged;
  final VoidCallback? onOpenInGoogle;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final TextTheme text = Theme.of(context).textTheme;
    final Color dot = parseHexColor(colorHex) ?? context.colors.primary;
    final List<String> subtitleParts = <String>[
      if (dataStale) l10n.calendarDataStale,
      // The state in words, so the switch position is never the only carrier.
      selected ? l10n.calendarSourceVisible : l10n.calendarSourceHidden,
    ];
    return ListTile(
      // Colour is decorative; the name (title) carries the identity.
      leading: Container(
        width: AppSizes.iconSmall,
        height: AppSizes.iconSmall,
        decoration: BoxDecoration(color: dot, shape: BoxShape.circle),
      ),
      title: Text(label),
      subtitle: Text(subtitleParts.join(' · '), style: text.bodySmall),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (onOpenInGoogle != null)
            IconButton(
              tooltip: l10n.calendarOpenInGoogle,
              onPressed: onOpenInGoogle,
              icon: const Icon(AppIcons.open_in_new),
            ),
          Switch.adaptive(value: selected, onChanged: onChanged),
        ],
      ),
    );
  }
}
