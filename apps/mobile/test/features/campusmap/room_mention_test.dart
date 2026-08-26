// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

/// Which written mentions may become a room link.
///
/// Every test here is really the same question asked twice: does this string
/// certainly mean that room? A link says "tap this and you will be at the right
/// door", so anything short of certain has to stay plain text — walking someone
/// confidently to the wrong building is worse than making them search.
library;

import 'package:campus_koethen/features/campusmap/domain/room.dart';
import 'package:campus_koethen/features/campusmap/domain/room_mention.dart';
import 'package:flutter_test/flutter_test.dart';

Room room(String number, {String building = 'test-building'}) => Room(
  roomKey: '$building-${number.toLowerCase().replaceAll('.', '')}',
  roomNumber: number,
  buildingKey: building,
  buildingName: 'Testgebäude',
  floorKey: '$building-level2',
  floorName: '2. Obergeschoss',
  roomType: RoomType.office,
  mapVersion: 'demo-1',
  sortOrder: 0,
);

void main() {
  final RoomResolver resolver = RoomResolver.fromRooms(<Room>[
    room('B.202'),
    room('B.210'),
    room('C.14', building: 'demo-south'),
  ]);

  group('a field that holds a room designation', () {
    test('resolves every spelling of the number', () {
      for (final String written in <String>[
        'B.202',
        'B202',
        'b 202',
        'B-202',
      ]) {
        expect(
          resolver.resolveDesignation(written)?.roomNumber,
          'B.202',
          reason: 'written as "$written"',
        );
      }
    });

    test(
      'accepts the short form, because the field is known to hold a room',
      () {
        expect(resolver.resolveDesignation('202')?.roomNumber, 'B.202');
        expect(resolver.resolveDesignation('14')?.roomNumber, 'C.14');
      },
    );

    test('does not complete a partial number', () {
      // "B.2" is not B.202. Guessing here is exactly the heuristic that would
      // send somebody to the wrong door.
      expect(resolver.resolveDesignation('B.2'), isNull);
      expect(resolver.resolveDesignation('20'), isNull);
      expect(resolver.resolveDesignation('B.2020'), isNull);
    });

    test('resolves nothing for an empty or unknown value', () {
      expect(resolver.resolveDesignation(''), isNull);
      expect(resolver.resolveDesignation('   '), isNull);
      expect(resolver.resolveDesignation('Online'), isNull);
      expect(resolver.resolveDesignation('nach Absprache'), isNull);
    });

    test('refuses a short form that two buildings share', () {
      final RoomResolver ambiguous = RoomResolver.fromRooms(<Room>[
        room('B.202'),
        room('C.202', building: 'demo-south'),
      ]);

      // Nobody can tell which one "202" meant, so it means neither.
      expect(ambiguous.resolveDesignation('202'), isNull);
      // The qualified forms still work — they were never ambiguous.
      expect(
        ambiguous.resolveDesignation('B.202')?.roomKey,
        'test-building-b202',
      );
      expect(ambiguous.resolveDesignation('C.202')?.roomKey, 'demo-south-c202');
    });

    test('grouped room labels resolve each represented number', () {
      final Room grouped = room('223–225', building: 'ratke-gebaeude');
      final RoomResolver groupedResolver = RoomResolver.fromRooms(<Room>[
        grouped,
      ]);

      expect(
        groupedResolver.resolveDesignation('223')?.roomKey,
        grouped.roomKey,
      );
      expect(
        groupedResolver.resolveDesignation('224')?.roomKey,
        grouped.roomKey,
      );
      expect(
        groupedResolver.resolveDesignation('225')?.roomKey,
        grouped.roomKey,
      );
    });

    test('a bare number is ambiguous across two buildings', () {
      final Room ratke = room('202', building: 'ratke-gebaeude');
      final Room otherBuilding = room('B.202');
      final RoomResolver ambiguous = RoomResolver.fromRooms(<Room>[
        ratke,
        otherBuilding,
      ]);

      expect(ambiguous.resolveDesignation('202'), isNull);
      expect(
        ambiguous.resolveDesignation('B.202')?.roomKey,
        otherBuilding.roomKey,
      );
    });
  });

  group('prose from a public calendar', () {
    test('resolves a fully qualified mention', () {
      final List<Room> found = resolver.findInText(
        'Sprechstunde in Raum B.202, bitte anmelden',
      );
      expect(found.single.roomNumber, 'B.202');
    });

    test('ignores a bare number, whatever it might mean', () {
      // A year, a course number, a house number, a price — prose is full of
      // numbers, and none of them may become a link to a room.
      expect(resolver.findInText('Treffen 2026 um 14 Uhr'), isEmpty);
      expect(resolver.findInText('Raum 202'), isEmpty);
      expect(resolver.findInText('Beitrag: 14 Euro'), isEmpty);
    });

    test('ignores a number embedded in a word', () {
      expect(resolver.findInText('Modul INF202 startet'), isEmpty);
      expect(resolver.findInText('B.202a ist etwas anderes'), isEmpty);
    });

    test('does not invent a room that is not in the catalogue', () {
      expect(resolver.findInText('Treffen in A.999'), isEmpty);
    });

    test('finds several rooms, each only once', () {
      final List<Room> found = resolver.findInText(
        'Start B.202, dann C.14, Rückkehr nach B.202',
      );
      expect(found.map((Room r) => r.roomNumber), <String>['B.202', 'C.14']);
    });

    test('an empty text resolves to nothing', () {
      expect(resolver.findInText(''), isEmpty);
      expect(resolver.findInText('   '), isEmpty);
    });
  });

  group('resolve() applies the rule that fits the source', () {
    test('the same string means different things by source', () {
      const String prose = 'Raum 202';
      // As a designation the whole value is the room; as prose it is a number
      // in a sentence.
      expect(
        resolver.resolve('202', RoomMentionSource.designation),
        hasLength(1),
      );
      expect(resolver.resolve(prose, RoomMentionSource.freeText), isEmpty);
    });

    test('null and blank resolve to nothing for both sources', () {
      for (final RoomMentionSource source in RoomMentionSource.values) {
        expect(resolver.resolve(null, source), isEmpty);
        expect(resolver.resolve('  ', source), isEmpty);
      }
    });
  });

  test('an empty catalogue resolves nothing rather than throwing', () {
    const RoomResolver empty = RoomResolver.empty();
    expect(empty.isEmpty, isTrue);
    expect(empty.resolveDesignation('B.202'), isNull);
    expect(empty.findInText('Raum B.202'), isEmpty);
  });
}
