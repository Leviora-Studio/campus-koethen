// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_dimensions.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/widgets/campus_location_filter.dart';
import '../../../core/theme/hex_color.dart';
import '../../../l10n/l10n.dart';
import '../application/event_providers.dart';
import '../application/event_source_filter.dart';

/// The event overview's own, eigenständiger multi-select source filter — a
/// modal bottom sheet with "Alle auswählen"/"Alle abwählen" and per-source
/// checkboxes, entirely separate from the news feed's channel filter and the
/// calendar's public-calendar selection.
Future<void> showEventSourceFilterSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (BuildContext context) => const _EventSourceFilterSheet(),
  );
}

class _EventSourceFilterSheet extends ConsumerWidget {
  const _EventSourceFilterSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final List<EventSourceOption> options =
        ref.watch(eventSourceOptionsProvider).value ??
        const <EventSourceOption>[];
    final location = ref.watch(eventLocationFilterProvider);
    final visible = eventOptionsAtLocation(options, location);
    final EventSourceFilterState filter = ref.watch(eventSourceFilterProvider);
    final Set<String> selected = EventSourceFilterRules.effectiveSelection(
      available: options,
      selected: filter.selectedKeys,
    );

    Future<void> setAll(bool value) async {
      final EventSourceFilterController notifier = ref.read(
        eventSourceFilterProvider.notifier,
      );
      for (final EventSourceOption option in visible) {
        await notifier.setSelected(option.key, selected: value);
      }
    }

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
                child: Text(
                  l10n.eventSourceFilterTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
            CampusLocationFilter(
              locations: options.map((option) => option.location),
              selected: location,
              onChanged: ref.read(eventLocationFilterProvider.notifier).select,
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Row(
                children: <Widget>[
                  TextButton(
                    onPressed: options.isEmpty ? null : () => setAll(true),
                    child: Text(l10n.eventSourceFilterSelectAll),
                  ),
                  TextButton(
                    onPressed: options.isEmpty ? null : () => setAll(false),
                    child: Text(l10n.eventSourceFilterDeselectAll),
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    for (final EventSourceOption option in visible)
                      CheckboxListTile(
                        value: selected.contains(option.key),
                        title: Text(option.label),
                        subtitle: option.location == null
                            ? null
                            : Text(option.location!.name),
                        secondary: switch (parseHexColor(option.colorHex)) {
                          final Color color => Icon(
                            AppIcons.circle_outlined,
                            color: color,
                            size: AppSizes.iconSmall,
                          ),
                          null => null,
                        },
                        controlAffinity: ListTileControlAffinity.leading,
                        onChanged: (bool? value) => ref
                            .read(eventSourceFilterProvider.notifier)
                            .setSelected(option.key, selected: value ?? false),
                      ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              child: Align(
                alignment: AlignmentDirectional.centerEnd,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l10n.eventSourceFilterDone),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
