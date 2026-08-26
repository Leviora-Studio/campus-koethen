// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:flutter/material.dart';
import "package:campus_koethen/core/theme/app_icons.dart";

import '../../../core/locale/formatters.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/widgets/sheet_body.dart';
import '../../../l10n/l10n.dart';
import '../data/canteen_models.dart';
import '../domain/meal_taxonomy.dart';
import 'meal_taxonomy_labels.dart';

/// Opens the price overview of one meal as a modal bottom sheet.
///
/// [knownPriceGroups] is the price vocabulary of the whole day's offer — one
/// sample [MealPrice] per group, used only for its `group` key and `label`.
/// A group this specific [meal] does not price still gets a row, marked
/// unavailable, instead of silently vanishing from the overview.
///
/// Opening the sheet never changes [priceGroup]: it states which group is
/// currently selected, it does not offer to change it — that stays the job
/// of the filter.
Future<void> showMealPriceOverviewSheet(
  BuildContext context, {
  required Meal meal,
  required String priceGroup,
  required List<MealPrice> knownPriceGroups,
}) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    useSafeArea: true,
    isScrollControlled: true,
    builder: (BuildContext _) => _MealPriceOverviewSheet(
      meal: meal,
      priceGroup: priceGroup,
      knownPriceGroups: knownPriceGroups,
    ),
  );
}

class _MealPriceOverviewSheet extends StatelessWidget {
  const _MealPriceOverviewSheet({
    required this.meal,
    required this.priceGroup,
    required this.knownPriceGroups,
  });

  final Meal meal;
  final String priceGroup;
  final List<MealPrice> knownPriceGroups;

  /// The meal's allergens in taxonomy order, so two dishes never list the
  /// same set in a different sequence.
  List<MealAllergen> get _sortedAllergens => MealAllergen.values
      .where((MealAllergen a) => meal.allergens.contains(a))
      .toList(growable: false);

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final TextTheme text = Theme.of(context).textTheme;

    // The meal's own prices win over the day's vocabulary sample: a price
    // group must be shown with the actual number for this dish, never with
    // another dish's amount for the same group.
    final Map<String, MealPrice> byGroup = <String, MealPrice>{
      for (final MealPrice price in knownPriceGroups) price.group: price,
      for (final MealPrice price in meal.prices) price.group: price,
    };

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.xl,
      ),
      child: SheetBody(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Semantics(
              header: true,
              child: Text(
                l10n.canteenPriceOverviewTitle,
                style: text.headlineSmall,
              ),
            ),
            const SizedBox(height: AppSpacing.xxs),
            Text(meal.name, style: text.bodyMedium),
            const SizedBox(height: AppSpacing.md),
            for (final MealPrice group in byGroup.values)
              _PriceRow(
                group: group,
                actualPrice: meal.priceFor(group.group),
                isSelected: group.group == priceGroup,
              ),

            // The declared allergens were in the model and reachable only
            // through the exclusion filter — so someone checking what is
            // actually in one dish had no way to look. That is health
            // information, not a filter convenience.
            const SizedBox(height: AppSpacing.lg),
            Semantics(
              header: true,
              child: Text(l10n.canteenAllergensTitle, style: text.titleSmall),
            ),
            const SizedBox(height: AppSpacing.xs),
            if (meal.allergens.isEmpty)
              Text(l10n.canteenAllergensNone, style: text.bodyMedium)
            else
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: <Widget>[
                  for (final MealAllergen allergen in _sortedAllergens)
                    Chip(
                      label: Text(mealAllergenLabel(l10n, allergen)),
                      visualDensity: VisualDensity.compact,
                    ),
                ],
              ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              l10n.canteenAllergensDisclaimer,
              style: text.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PriceRow extends StatelessWidget {
  const _PriceRow({
    required this.group,
    required this.actualPrice,
    required this.isSelected,
  });

  /// Sample price carrying this group's stable key and localized label.
  final MealPrice group;

  /// The meal's actual price for [group], or `null` when the API did not
  /// deliver one — never invented as `0,00 €`.
  final MealPrice? actualPrice;

  final bool isSelected;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AppColors colors = context.colors;
    final TextTheme text = Theme.of(context).textTheme;
    final String locale = Localizations.localeOf(context).languageCode;
    final MealPrice? actualPrice = this.actualPrice;

    final String? formatted = actualPrice == null
        ? null
        : MoneyFormatter.format(
            amount: actualPrice.amount,
            currencyCode: actualPrice.currency,
            locale: locale,
          );
    final String valueText = formatted ?? l10n.canteenPriceOverviewUnavailable;

    final String semanticLabel = isSelected
        ? '${l10n.canteenPriceOverviewSelectedLabel}. '
              '${l10n.canteenPriceSemanticLabel(group.label, valueText)}'
        : l10n.canteenPriceSemanticLabel(group.label, valueText);

    return Semantics(
      label: semanticLabel,
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: AppSizes.minTouchTarget),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Text(
                group.label,
                style: isSelected
                    ? text.bodyLarge?.copyWith(fontWeight: FontWeight.w600)
                    : text.bodyLarge,
              ),
            ),
            if (isSelected) ...<Widget>[
              Icon(
                AppIcons.check,
                size: AppSizes.iconSmall,
                color: colors.primary,
              ),
              const SizedBox(width: AppSpacing.xs),
            ],
            Text(
              valueText,
              style: formatted == null
                  ? text.bodyMedium?.copyWith(color: colors.textSecondary)
                  : text.bodyLarge?.copyWith(
                      fontWeight: isSelected ? FontWeight.w600 : null,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
