// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import "package:campus_koethen/core/theme/app_icons.dart";

import '../../../core/theme/app_dimensions.dart';
import '../../../core/widgets/sheet_body.dart';
import '../../../l10n/l10n.dart';
import '../application/canteen_filter_controller.dart';
import '../data/canteen_models.dart';
import '../domain/canteen_filter.dart';
import '../domain/meal_taxonomy.dart';
import 'meal_taxonomy_labels.dart';

/// Filter sheet for the canteen.
///
/// The vocabulary is **fixed**, not built from the visible day. A filter that
/// appears and disappears with the day's offer cannot be relied on, and "no
/// peanuts" has to mean the same thing on a Tuesday as on a Friday. It is also
/// the API's own taxonomy rather than the source's marker codes — see
/// [MealAllergen].
///
/// Nothing selected here leaves the device.
Future<void> showCanteenFilterSheet(
  BuildContext context,
  List<MealPrice> availablePrices,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (BuildContext _) => _CanteenFilterSheet(prices: availablePrices),
  );
}

class _CanteenFilterSheet extends ConsumerWidget {
  const _CanteenFilterSheet({required this.prices});

  /// The price groups the API delivered, so the choice cannot offer a group
  /// this canteen does not have.
  final List<MealPrice> prices;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final CanteenFilter filter = ref.watch(canteenFilterProvider);
    final CanteenFilterController controller = ref.read(
      canteenFilterProvider.notifier,
    );
    final TextTheme text = Theme.of(context).textTheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      child: SheetBody(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Semantics(
              header: true,
              child: Text(l10n.canteenFilterTitle, style: text.headlineSmall),
            ),
            const SizedBox(height: AppSpacing.xs),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: filter.isActive ? controller.clear : null,
                icon: const Icon(AppIcons.filter_alt_off_outlined),
                label: Text(l10n.canteenFilterClear),
              ),
            ),
            const SizedBox(height: AppSpacing.md),

            Semantics(
              header: true,
              child: Text(
                l10n.canteenFilterMustContain,
                style: text.titleSmall,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: <Widget>[
                for (final MealTrait trait in MealTrait.values)
                  FilterChip(
                    label: Text(mealTraitLabel(l10n, trait)),
                    selected: filter.requiredTraits.contains(trait),
                    onSelected: (_) => controller.toggleTrait(trait),
                  ),
              ],
            ),

            const SizedBox(height: AppSpacing.lg),
            Semantics(
              header: true,
              child: Text(
                l10n.canteenFilterMustNotContain,
                style: text.titleSmall,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            for (final MealAllergen allergen in allergenTopLevel)
              _AllergenTile(
                allergen: allergen,
                filter: filter,
                controller: controller,
              ),

            if (prices.isNotEmpty) ...<Widget>[
              const SizedBox(height: AppSpacing.lg),
              Semantics(
                header: true,
                child: Text(
                  l10n.canteenPriceGroupSection,
                  style: text.titleSmall,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              // Exactly one group: a card shows one price, for one person.
              RadioGroup<String>(
                groupValue: filter.priceGroup,
                onChanged: (String? group) {
                  if (group != null) controller.setPriceGroup(group);
                },
                child: Column(
                  children: <Widget>[
                    for (final MealPrice price in prices)
                      RadioListTile<String>(
                        contentPadding: EdgeInsets.zero,
                        value: price.group,
                        title: Text(price.label),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One allergen, with its subtypes underneath when it has any.
///
/// Ticking the parent excludes every dish the source declared for the facet,
/// including those that only name a subtype — and visibly checks every
/// subtype underneath, so the covered selection is never silently implicit.
/// Ticking one subtype on its own excludes exactly that one — a dish declared
/// merely as "contains gluten" is not evidence of wheat. When only some
/// subtypes are ticked, the parent shows a distinct, explicitly labelled
/// partial state rather than looking simply unchecked.
class _AllergenTile extends StatelessWidget {
  const _AllergenTile({
    required this.allergen,
    required this.filter,
    required this.controller,
  });

  final MealAllergen allergen;
  final CanteenFilter filter;
  final CanteenFilterController controller;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final List<MealAllergen> subtypes = subtypesOf(allergen);

    if (subtypes.isEmpty) {
      return CheckboxListTile(
        contentPadding: EdgeInsets.zero,
        value: filter.isAllergenExcluded(allergen),
        // A check mark and the word, never a colour on its own.
        title: Text(mealAllergenLabel(l10n, allergen)),
        controlAffinity: ListTileControlAffinity.leading,
        onChanged: (_) => controller.toggleAllergen(allergen),
      );
    }

    final bool partial = filter.isAllergenPartiallyExcluded(allergen);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        CheckboxListTile(
          contentPadding: EdgeInsets.zero,
          tristate: true,
          value: partial ? null : filter.isAllergenFullyExcluded(allergen),
          title: Text(
            partial
                ? l10n.canteenFilterAllergenPartial(
                    mealAllergenLabel(l10n, allergen),
                  )
                : mealAllergenLabel(l10n, allergen),
          ),
          controlAffinity: ListTileControlAffinity.leading,
          onChanged: (_) => controller.toggleAllergen(allergen),
        ),
        for (final MealAllergen subtype in subtypes)
          CheckboxListTile(
            contentPadding: const EdgeInsets.only(left: AppSpacing.xl),
            value: filter.isAllergenExcluded(subtype),
            title: Text(mealAllergenLabel(l10n, subtype)),
            controlAffinity: ListTileControlAffinity.leading,
            onChanged: (_) => controller.toggleAllergen(subtype),
          ),
      ],
    );
  }
}
