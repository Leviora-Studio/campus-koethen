// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:campus_koethen/features/campusmap/domain/room.dart';
import 'package:flutter_test/flutter_test.dart';

Room _room(String key) => Room(
  roomKey: key,
  roomNumber: key.toUpperCase(),
  buildingKey: 'test-building',
  buildingName: 'Testgebäude',
  floorKey: 'test-building-level2',
  floorName: '2. Obergeschoss',
  roomType: RoomType.seminar,
  mapVersion: '1',
  sortOrder: 0,
);

void main() {
  group('roomWithKey', () {
    final List<Room> rooms = <Room>[_room('b201'), _room('b202')];

    test('finds a room by its key', () {
      expect(roomWithKey(rooms, 'b202')?.roomKey, 'b202');
    });

    test('a key the response does not carry is not a match', () {
      // A deep link or a bundled geometry may name a room the server did not
      // send; that has to stay "no room", never a wrong one.
      expect(roomWithKey(rooms, 'b999'), isNull);
    });

    test('no selection is not a lookup', () {
      expect(roomWithKey(rooms, null), isNull);
    });

    test('the index is built once per loaded list', () {
      expect(identical(roomsByKey(rooms), roomsByKey(rooms)), isTrue);
      expect(
        identical(roomsByKey(rooms), roomsByKey(<Room>[...rooms])),
        isFalse,
      );
    });

    test('an empty response answers nothing', () {
      expect(roomWithKey(const <Room>[], 'b201'), isNull);
    });
  });
}
