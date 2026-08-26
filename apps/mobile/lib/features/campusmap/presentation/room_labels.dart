// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:flutter/widgets.dart';

import '../../../l10n/l10n.dart';
import '../domain/room.dart';

/// Localised labels for the technical room vocabulary.
///
/// The API sends stable keys such as `lecture`; the wording lives here so both
/// languages stay in the ARB files and a future key cannot leak an
/// untranslated string into the UI.
String roomTypeLabel(BuildContext context, RoomType type) {
  final AppLocalizations l10n = context.l10n;
  switch (type) {
    case RoomType.room:
      return l10n.campusMapRoomTypeRoom;
    case RoomType.lecture:
      return l10n.campusMapRoomTypeLecture;
    case RoomType.seminar:
      return l10n.campusMapRoomTypeSeminar;
    case RoomType.office:
      return l10n.campusMapRoomTypeOffice;
    case RoomType.lab:
      return l10n.campusMapRoomTypeLab;
    case RoomType.meeting:
      return l10n.campusMapRoomTypeMeeting;
    case RoomType.service:
      return l10n.campusMapRoomTypeService;
    case RoomType.unknown:
      return l10n.campusMapRoomTypeUnknown;
  }
}

/// "Building, floor, room B.201" — the readable one-line form of a location.
String roomLocationSummary(
  BuildContext context, {
  required String buildingName,
  required String buildingNumber,
  required String floorName,
  required String roomNumber,
}) => buildingNumber.isEmpty
    ? context.l10n.contactRoomSummary(buildingName, floorName, roomNumber)
    : context.l10n.contactRoomSummaryWithBuildingNumber(
        roomNumber,
        buildingNumber,
        buildingName,
        floorName,
      );
