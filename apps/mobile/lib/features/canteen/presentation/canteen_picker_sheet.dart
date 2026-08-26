// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import "package:campus_koethen/core/theme/app_icons.dart";

import '../../../core/network/loaded.dart';
import '../../../core/prefs/settings_controller.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/widgets/state_views.dart';
import '../../../l10n/l10n.dart';
import '../application/canteen_providers.dart';
import '../data/canteen_models.dart';

/// Opens the canteen picker as a modal bottom sheet.
Future<void> showCanteenPickerSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (BuildContext context) => const SafeArea(
      child: Padding(
        padding: EdgeInsets.only(bottom: AppSpacing.lg),
        child: CanteenPickerList(showTitle: true),
      ),
    ),
  );
}

/// Lists the canteens the API offers and stores the choice locally.
class CanteenPickerList extends ConsumerWidget {
  const CanteenPickerList({this.showTitle = false, super.key});

  final bool showTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<Loaded<List<Canteen>>> canteens = ref.watch(
      canteensProvider,
    );
    final String? selected = ref.watch(selectedCanteenSlugProvider);

    return switch (canteens) {
      AsyncLoading<Loaded<List<Canteen>>>() when !canteens.hasValue =>
        const Padding(
          padding: EdgeInsets.all(AppSpacing.xl),
          child: LoadingView(),
        ),
      AsyncError<Loaded<List<Canteen>>>(:final Object error) => Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: ErrorView(
          failure: error,
          onRetry: () => ref.invalidate(canteensProvider),
        ),
      ),
      _ => _buildList(
        context,
        ref,
        l10n,
        canteens.requireValue.value,
        selected,
      ),
    };
  }

  Widget _buildList(
    BuildContext context,
    WidgetRef ref,
    AppLocalizations l10n,
    List<Canteen> canteens,
    String? selected,
  ) {
    if (canteens.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppSpacing.xl),
        child: EmptyView(
          icon: AppIcons.restaurant_outlined,
          title: l10n.canteenNoCanteensTitle,
          message: l10n.canteenNoCanteensMessage,
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (showTitle)
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
                l10n.canteenPickerTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
          ),
        RadioGroup<String>(
          groupValue: selected,
          onChanged: (String? value) async {
            await ref
                .read(settingsProvider.notifier)
                .setPreferredCanteen(value);
            if (context.mounted) await Navigator.of(context).maybePop();
          },
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (final Canteen canteen in canteens)
                RadioListTile<String>.adaptive(
                  value: canteen.slug,
                  title: Text(canteen.displayName),
                  subtitle: canteen.campusLabel == null
                      ? null
                      : Text(canteen.campusLabel!),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
