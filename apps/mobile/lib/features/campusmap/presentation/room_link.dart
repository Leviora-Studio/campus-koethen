// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import "package:campus_koethen/core/theme/app_icons.dart";

import '../../../app/app_routes.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../l10n/l10n.dart';
import '../../contacts/data/contact_models.dart';
import '../application/campus_map_providers.dart';
import '../domain/map_catalog.dart';
import '../domain/room.dart';

/// Everything a room link needs to render, from wherever the room came from.
///
/// Contacts deliver a [RoomReference], the catalogue a [Room], and a resolved
/// mention in a calendar entry a [Room] again. They differ in what else they
/// carry, not in what a link shows — so they meet here rather than growing a
/// second room row per feature.
@immutable
class RoomLinkTarget {
  const RoomLinkTarget({
    required this.roomKey,
    required this.roomNumber,
    this.buildingNumber = '',
    required this.buildingName,
    required this.floorName,
    this.displayName,
  });

  RoomLinkTarget.fromRoom(Room room)
    : roomKey = room.roomKey,
      roomNumber = room.roomNumber,
      buildingNumber = room.buildingNumber,
      buildingName = room.buildingName,
      floorName = room.floorName,
      displayName = room.displayName;

  RoomLinkTarget.fromReference(RoomReference room)
    : roomKey = room.roomKey,
      roomNumber = room.roomNumber,
      buildingNumber = room.buildingNumber,
      buildingName = room.buildingName,
      floorName = room.floorName,
      displayName = room.displayName;

  final String roomKey;
  final String roomNumber;
  final String buildingNumber;
  final String buildingName;
  final String floorName;
  final String? displayName;

  String get label => displayName ?? roomNumber;
}

/// Opens the campus map on [roomKey].
///
/// [closeSheet] pops whatever is open first — a detail sheet that stayed above
/// the map would hide the very room it was asked to show. The router is taken
/// before popping, because the context is gone afterwards.
void openRoomOnMap(
  BuildContext context,
  String roomKey, {
  bool closeSheet = false,
}) {
  final GoRouter router = GoRouter.of(context);
  final NavigatorState navigator = Navigator.of(context);
  if (closeSheet && navigator.canPop()) navigator.pop();
  router.push(AppRoutes.campusMapForRoom(roomKey));
}

/// Whether the bundled plan can actually show a room.
///
/// An older app with a newer catalogue knows the room by name but has no
/// geometry for it. Linking there would open an empty map, so the caller
/// renders plain text instead.
bool roomIsOnMap(WidgetRef ref, String roomKey) {
  final MapCatalog? catalog = ref.watch(mapCatalogProvider).value;
  return catalog?.geometryFor(roomKey) != null;
}

/// One room row: the room, where it is, and a way to the map.
///
/// When the bundled map does not know the room the row stays plain, readable
/// text — never a link that leads nowhere.
class RoomLinkTile extends ConsumerWidget {
  const RoomLinkTile({required this.room, this.closeSheet = false, super.key});

  final RoomLinkTarget room;

  /// Set where the tile lives inside a bottom sheet.
  final bool closeSheet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    final bool onMap = roomIsOnMap(ref, room.roomKey);

    final String summary = room.buildingNumber.isEmpty
        ? l10n.contactRoomSummary(
            room.buildingName,
            room.floorName,
            room.roomNumber,
          )
        : l10n.contactRoomSummaryWithBuildingNumber(
            room.roomNumber,
            room.buildingNumber,
            room.buildingName,
            room.floorName,
          );

    return ListTile(
      leading: const Icon(AppIcons.place_outlined),
      title: Text(room.label),
      subtitle: Text(
        onMap ? summary : '$summary\n${l10n.campusMapRoomNotOnMap}',
      ),
      isThreeLine: !onMap,
      trailing: onMap ? const Icon(AppIcons.chevron_right) : null,
      minTileHeight: AppSizes.minTouchTarget,
      onTap: onMap
          ? () => openRoomOnMap(context, room.roomKey, closeSheet: closeSheet)
          : null,
    );
  }
}

/// The compact form for a detail sheet, where a full row would dominate.
///
/// Still a real button with a real label — never an icon alone — and still
/// silent about the map when the room is not on it.
class RoomLinkButton extends ConsumerWidget {
  const RoomLinkButton({required this.room, this.closeSheet = true, super.key});

  final RoomLinkTarget room;
  final bool closeSheet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final AppLocalizations l10n = context.l10n;
    if (!roomIsOnMap(ref, room.roomKey)) {
      return Text(
        l10n.campusMapRoomNotOnMap,
        style: Theme.of(context).textTheme.bodySmall,
      );
    }

    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: OutlinedButton.icon(
        icon: const Icon(AppIcons.place_outlined),
        label: Text(l10n.campusMapShowRoom(room.label)),
        onPressed: () =>
            openRoomOnMap(context, room.roomKey, closeSheet: closeSheet),
      ),
    );
  }
}

/// The rooms of a contact, with a heading. Renders nothing when there are none,
/// so a contact without a room looks exactly as it did before.
class RoomLinkSection extends StatelessWidget {
  const RoomLinkSection({required this.rooms, super.key});

  final List<RoomReference> rooms;

  @override
  Widget build(BuildContext context) {
    if (rooms.isEmpty) return const SizedBox.shrink();
    final AppLocalizations l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const SizedBox(height: AppSpacing.md),
        Text(
          l10n.contactRoomsLabel,
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: AppSpacing.xs),
        ...rooms.map(
          (RoomReference room) =>
              RoomLinkTile(room: RoomLinkTarget.fromReference(room)),
        ),
      ],
    );
  }
}
