// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import "package:campus_koethen/core/theme/app_icons.dart";

import '../../../core/network/loaded.dart';
import '../../../core/prefs/settings_controller.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../core/widgets/state_views.dart';
import '../../../core/widgets/translation_fallback_notice.dart';
import '../../../l10n/l10n.dart';
import '../../notifications/presentation/pre_permission_sheet.dart';
import '../application/timetable_providers.dart';
import '../data/timetable_models.dart';

/// Opens the course picker as a modal bottom sheet.
///
/// The sheet is scroll controlled because the API delivers the full group list
/// (roughly 270 entries) in one response; the search narrows it down locally,
/// which also keeps working offline.
///
/// Choosing a group for the first time is contextual entry point C of the UX
/// spec (§ 2.2): it is the moment somebody says which lectures are theirs, and
/// therefore the moment the daily overview at 08:00 becomes worth offering.
/// The offer runs from the **caller's** context, after the sheet has closed —
/// a sheet cannot open another one on top of its own disposal — and asks only
/// under the conditions [maybeOfferNotificationOptIn] guards, so a reader who
/// has already answered is never asked again.
Future<void> showTimetableGroupPickerSheet(
  BuildContext context,
  WidgetRef ref,
) async {
  final String? before = ref.read(selectedTimetableGroupIdProvider);
  await showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    // A modal bottom sheet is not resized for the keyboard on its own — the
    // sheet's own height factor is computed against the full screen height
    // regardless of how much of it the keyboard covers. Without this padding
    // a large keyboard simply sits on top of the sheet, hiding the search
    // field it was meant to be typed into.
    builder: (BuildContext context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: FractionallySizedBox(
        heightFactor: 0.9,
        child: const SafeArea(child: TimetableGroupPickerList()),
      ),
    ),
  );

  if (!context.mounted) return;
  final String? after = ref.read(selectedTimetableGroupIdProvider);
  if (after == null || after == before) return;
  await maybeOfferNotificationOptIn(context, ref);
}

/// Searchable list of all study groups. Exactly one group can be selected.
class TimetableGroupPickerList extends ConsumerStatefulWidget {
  const TimetableGroupPickerList({super.key});

  @override
  ConsumerState<TimetableGroupPickerList> createState() =>
      _TimetableGroupPickerListState();
}

class _TimetableGroupPickerListState
    extends ConsumerState<TimetableGroupPickerList> {
  final TextEditingController _search = TextEditingController();

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final AsyncValue<Loaded<List<TimetableGroup>>> groups = ref.watch(
      timetableGroupsProvider,
    );
    final String? selected = ref.watch(selectedTimetableGroupIdProvider);

    // A CustomScrollView rather than a fixed header plus an `Expanded` list:
    // on a small viewport with a large keyboard and scaled-up text, the
    // title and search field alone can already exceed the sheet's height, and
    // an `Expanded` cannot give them less than they ask for — it overflows
    // instead. Slivers let the header scroll away with the list rather than
    // forcing space it does not have.
    // The RadioGroup wraps the whole scroll view rather than just the list
    // sliver: it renders a `Semantics` node of its own, which — like any
    // other box widget — cannot take a sliver as its child. Wrapping the
    // CustomScrollView keeps it a plain box widget; the RadioListTiles below
    // still find it through the element tree regardless of the sliver
    // nesting in between.
    final NavigatorState navigator = Navigator.of(context);
    return RadioGroup<String>(
      groupValue: selected,
      onChanged: (String? value) async {
        await ref.read(settingsProvider.notifier).setTimetableGroup(value);
        if (mounted) await navigator.maybePop();
      },
      child: CustomScrollView(
        slivers: <Widget>[
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.sm,
              ),
              child: Semantics(
                header: true,
                child: Text(
                  l10n.timetableGroupPickerTitle,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
              child: TextField(
                controller: _search,
                textInputAction: TextInputAction.search,
                onChanged: (String _) => setState(() {}),
                decoration: InputDecoration(
                  labelText: l10n.timetableGroupSearchLabel,
                  hintText: l10n.timetableGroupSearchHint,
                  prefixIcon: const Icon(AppIcons.search),
                ),
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: AppSpacing.sm)),
          switch (groups) {
            AsyncLoading<Loaded<List<TimetableGroup>>>()
                when !groups.hasValue =>
              const SliverFillRemaining(child: LoadingView()),
            AsyncError<Loaded<List<TimetableGroup>>>(:final Object error) =>
              SliverFillRemaining(
                child: ErrorView(
                  failure: error,
                  onRetry: () => ref.invalidate(timetableGroupsProvider),
                ),
              ),
            _ => _buildList(l10n, groups.requireValue),
          },
        ],
      ),
    );
  }

  Widget _buildList(
    AppLocalizations l10n,
    Loaded<List<TimetableGroup>> loaded,
  ) {
    final List<TimetableGroup> groups = loaded.value;
    if (groups.isEmpty) {
      return SliverFillRemaining(
        child: EmptyView(
          icon: AppIcons.school_outlined,
          title: l10n.timetableNoGroupsTitle,
          message: l10n.timetableNoGroupsMessage,
        ),
      );
    }

    final String query = _search.text.trim().toLowerCase();
    final List<TimetableGroup> matches = query.isEmpty
        ? groups
        : groups
              .where((TimetableGroup group) => group.matchesNeedle(query))
              .toList(growable: false);

    if (matches.isEmpty) {
      return SliverFillRemaining(
        child: EmptyView(
          icon: AppIcons.search_off_outlined,
          title: l10n.timetableGroupSearchEmptyTitle,
          message: l10n.timetableGroupSearchEmptyMessage,
        ),
      );
    }

    return SliverMainAxisGroup(
      slivers: <Widget>[
        if (loaded.meta.translationFallback)
          const SliverPadding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.lg,
              0,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            sliver: SliverToBoxAdapter(child: TranslationFallbackNotice()),
          ),
        SliverPadding(
          padding: const EdgeInsets.only(bottom: AppSpacing.lg),
          sliver: SliverList.builder(
            itemCount: matches.length,
            itemBuilder: (BuildContext context, int index) {
              final TimetableGroup group = matches[index];
              return RadioListTile<String>.adaptive(
                value: group.id,
                title: Text(group.shortName),
                subtitle: _subtitle(group),
              );
            },
          ),
        ),
      ],
    );
  }

  /// Long name and department, both verbatim from the source system.
  Widget? _subtitle(TimetableGroup group) {
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
}
