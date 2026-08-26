// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:campus_koethen/features/campusmap/domain/map_catalog.dart';
import 'package:campus_koethen/features/campusmap/domain/map_hit_test.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

MapRoomGeometry _room(
  String key, {
  required Rect bounds,
  String floorKey = 'level2',
}) => MapRoomGeometry(
  roomKey: key,
  buildingKey: 'test-building',
  floorKey: floorKey,
  svgElementId: key,
  focus: bounds.center,
  bounds: bounds,
);

/// Two neighbours with a gap, and a small room inside a large one.
final MapRoomGeometry _left = _room(
  'left',
  bounds: const Rect.fromLTWH(0, 0, 100, 100),
);
final MapRoomGeometry _right = _room(
  'right',
  bounds: const Rect.fromLTWH(120, 0, 100, 100),
);
final MapRoomGeometry _hall = _room(
  'hall',
  bounds: const Rect.fromLTWH(0, 200, 300, 200),
);
final MapRoomGeometry _closet = _room(
  'closet',
  bounds: const Rect.fromLTWH(10, 210, 20, 20),
);

List<MapRoomGeometry> get _rooms => <MapRoomGeometry>[
  _left,
  _right,
  _hall,
  _closet,
];

String? _hit(Offset point, {double tolerance = 0}) =>
    hitTestRoom(_rooms, point, tolerance: tolerance)?.roomKey;

void main() {
  group('a tap inside a room', () {
    test('selects that room', () {
      expect(_hit(const Offset(50, 50)), 'left');
      expect(_hit(const Offset(150, 50)), 'right');
    });

    test('works on the edge, which is still the room', () {
      expect(_hit(const Offset(0, 0)), 'left');
      expect(_hit(const Offset(100, 100)), 'left');
    });

    test('picks the smaller room when one lies inside another', () {
      // A cupboard inside a hall: tapping the cupboard means the cupboard.
      expect(_hit(const Offset(20, 220)), 'closet');
      // …and the hall everywhere else.
      expect(_hit(const Offset(200, 300)), 'hall');
    });
  });

  group('a tap on empty floor', () {
    test('selects nothing', () {
      // Between the two rooms, and well outside the plan.
      expect(_hit(const Offset(110, 50)), isNull);
      expect(_hit(const Offset(500, 500)), isNull);
    });

    test('stays nothing even with a tolerance, once it is far enough away', () {
      expect(_hit(const Offset(110, 50), tolerance: 4), isNull);
      expect(_hit(const Offset(400, 50), tolerance: 20), isNull);
    });
  });

  group('the tolerance for small rooms', () {
    test('lets a near miss still hit its room', () {
      // A finger is wider than a cupboard drawn at map scale.
      expect(_hit(const Offset(-5, 50), tolerance: 8), 'left');
      expect(_hit(const Offset(50, 105), tolerance: 8), 'left');
    });

    test('never lets two rooms claim the same tap', () {
      // Right between the neighbours, within tolerance of both: the nearer one
      // wins rather than whichever happens to come first in the list.
      expect(_hit(const Offset(105, 50), tolerance: 20), 'left');
      expect(_hit(const Offset(115, 50), tolerance: 20), 'right');
    });

    test('an exact hit always beats a nearby room', () {
      // Inside "left" but close to "right": containment is not a matter of
      // distance.
      expect(_hit(const Offset(99, 50), tolerance: 40), 'left');
    });
  });

  test('only the rooms it is given are considered', () {
    // The caller passes the visible floor; a room one storey up must never
    // answer a tap.
    final List<MapRoomGeometry> otherFloor = <MapRoomGeometry>[
      _room(
        'upstairs',
        bounds: const Rect.fromLTWH(0, 0, 100, 100),
        floorKey: 'level3',
      ),
    ];
    expect(hitTestRoom(otherFloor, const Offset(50, 50))?.roomKey, 'upstairs');
    expect(
      hitTestRoom(const <MapRoomGeometry>[], const Offset(50, 50)),
      isNull,
    );
  });
}
