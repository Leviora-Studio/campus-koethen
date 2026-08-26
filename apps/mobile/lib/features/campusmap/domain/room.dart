// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:flutter/foundation.dart' show visibleForTesting;

import '../../../core/network/json.dart';

/// Stable technical room categories.
///
/// The Campus API sends a technical key, never a localised label, so a new
/// category on the server can never leak an untranslated German word into the
/// UI. [RoomType.unknown] keeps an unrecognised value from breaking the screen.
enum RoomType {
  room,
  lecture,
  seminar,
  office,
  lab,
  meeting,
  service,
  unknown;

  static RoomType fromKey(String? key) {
    switch (key) {
      case 'room':
        return RoomType.room;
      case 'lecture':
        return RoomType.lecture;
      case 'seminar':
        return RoomType.seminar;
      case 'office':
        return RoomType.office;
      case 'lab':
        return RoomType.lab;
      case 'meeting':
        return RoomType.meeting;
      case 'service':
        return RoomType.service;
      default:
        return RoomType.unknown;
    }
  }
}

/// One room of a bundled campus map, as served by `/v1/rooms`.
///
/// Editorial fields are optional; the UI hides what is missing instead of
/// rendering an empty row.
class Room {
  const Room({
    required this.roomKey,
    required this.roomNumber,
    required this.buildingKey,
    this.buildingNumber = '',
    required this.buildingName,
    required this.floorKey,
    required this.floorName,
    required this.roomType,
    required this.mapVersion,
    required this.sortOrder,
    this.displayName,
    this.description,
  });

  final String roomKey;
  final String roomNumber;

  final String buildingKey;
  final String buildingNumber;
  final String buildingName;

  final String floorKey;
  final String floorName;

  final RoomType roomType;

  final String? displayName;
  final String? description;

  final String mapVersion;
  final int sortOrder;

  /// What a list row leads with: the editorial name when there is one.
  String get primaryLabel => displayName ?? roomNumber;

  static Room? fromJson(Object? json) {
    final Map<String, dynamic>? map = asJsonMap(json);
    if (map == null) return null;
    final String? roomKey = asString(map['roomKey']);
    if (roomKey == null) return null;

    return Room(
      roomKey: roomKey,
      roomNumber: asString(map['roomNumber']) ?? roomKey,
      buildingKey: asString(map['buildingKey']) ?? '',
      buildingNumber: asString(map['buildingNumber']) ?? '',
      buildingName: asString(map['buildingName']) ?? '',
      floorKey: asString(map['floorKey']) ?? '',
      floorName: asString(map['floorName']) ?? '',
      roomType: RoomType.fromKey(asString(map['roomType'])),
      displayName: asString(map['displayName']),
      description: asString(map['description']),
      mapVersion: asString(map['mapVersion']) ?? '',
      sortOrder: asInt(map['sortOrder']) ?? 0,
    );
  }

  static List<Room> listFromJson(Object? json) =>
      asList(json).map(Room.fromJson).whereType<Room>().toList()..sort(compare);

  /// The one ordering used everywhere, so lists never reshuffle between builds.
  static int compare(Room a, Room b) {
    final int order = a.sortOrder.compareTo(b.sortOrder);
    if (order != 0) return order;
    final int number = a.roomNumber.compareTo(b.roomNumber);
    return number != 0 ? number : a.roomKey.compareTo(b.roomKey);
  }
}

/// Cache for [roomsByKey], keyed by the loaded list instance itself.
///
/// The list comes from one loaded response and is reused unchanged across
/// every rebuild; a fresh load creates a new list, which gets its own entry.
final Expando<Map<String, Room>> _byKeyCache = Expando<Map<String, Room>>(
  'roomsByKey',
);

/// The rooms of one loaded response, indexed by [Room.roomKey].
///
/// The map screen looks a room up by key twice on every build — once for the
/// selection it draws, once inside the tap handler it hands to the plan — and
/// it rebuilds on every keystroke in the room search. Both used to walk the
/// whole list. The bundled catalogue is already indexed this way
/// (`MapCatalog.geometryFor`); this is the same answer for the API's own room
/// DTOs, which carry the names and the editorial text.
@visibleForTesting
Map<String, Room> roomsByKey(List<Room> rooms) => _byKeyCache[rooms] ??=
    <String, Room>{for (final Room room in rooms) room.roomKey: room};

/// The room with [roomKey], or `null` when this response has none.
///
/// A `null` is a normal state: a deep link or a bundled geometry may name a
/// room the server did not send.
Room? roomWithKey(List<Room> rooms, String? roomKey) =>
    roomKey == null ? null : roomsByKey(rooms)[roomKey];
