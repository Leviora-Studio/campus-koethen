// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:campus_koethen/features/contacts/data/contact_search_models.dart';
import 'package:campus_koethen/features/contacts/domain/contact_search.dart';
import 'package:flutter_test/flutter_test.dart';

ContactSearchArea _area({
  String slug = 'ssc',
  String name = 'Studierendenservice',
  String shortDescription = '',
  String descriptionText = '',
  String? generalEmail,
  String? phone,
  String? website,
  String? appointmentBookingUrl,
  String? address,
  String? openingHours,
  List<SearchRoom> rooms = const <SearchRoom>[],
  List<ContactSearchPerson> persons = const <ContactSearchPerson>[],
}) => ContactSearchArea(
  slug: slug,
  name: name,
  shortDescription: shortDescription,
  descriptionText: descriptionText,
  generalEmail: generalEmail,
  phone: phone,
  website: website,
  appointmentBookingUrl: appointmentBookingUrl,
  address: address,
  openingHours: openingHours,
  rooms: rooms,
  persons: persons,
);

ContactSearchPerson _person({
  String name = 'Demo Person',
  String? role,
  String? description,
  String? email,
  String? phone,
  String? website,
  List<SearchRoom> rooms = const <SearchRoom>[],
}) => ContactSearchPerson(
  name: name,
  role: role,
  description: description,
  email: email,
  phone: phone,
  website: website,
  rooms: rooms,
);

const SearchRoom _b201 = SearchRoom(
  roomKey: 'test-building-level2-b201',
  roomNumber: 'B.201',
  buildingNumber: '23',
  buildingName: 'Testgebäude',
  floorName: '2. Obergeschoss',
  displayName: 'Beratungsraum',
);

List<String> _names(List<ContactSearchHit> hits) => hits
    .map(
      (ContactSearchHit hit) => switch (hit) {
        AreaHit(:final ContactSearchArea area) => area.name,
        PersonHit(:final ContactSearchPerson person) => person.name,
      },
    )
    .toList(growable: false);

void main() {
  group('an empty term', () {
    test('is not a filter and finds nothing to show as results', () {
      // The screen falls back to the ordinary area list; a search with no term
      // is not "match everything".
      expect(searchContacts(<ContactSearchArea>[_area()], ''), isEmpty);
      expect(searchContacts(<ContactSearchArea>[_area()], '   '), isEmpty);
    });
  });

  group('areas', () {
    test('match by name', () {
      final List<ContactSearchHit> hits = searchContacts(<ContactSearchArea>[
        _area(name: 'Studierendenservice'),
        _area(slug: 'x', name: 'Prüfungsamt'),
      ], 'prüf');

      expect(_names(hits), <String>['Prüfungsamt']);
    });

    test('match by short description, long description and opening hours', () {
      expect(
        _names(
          searchContacts(<ContactSearchArea>[
            _area(shortDescription: 'Beratung zu BAföG'),
          ], 'bafög'),
        ),
        hasLength(1),
      );
      expect(
        _names(
          searchContacts(<ContactSearchArea>[
            _area(descriptionText: 'Wir helfen bei Härtefallanträgen.'),
          ], 'härtefall'),
        ),
        hasLength(1),
      );
      expect(
        _names(
          searchContacts(<ContactSearchArea>[
            _area(openingHours: 'Mo–Do 9–15 Uhr'),
          ], 'uhr'),
        ),
        hasLength(1),
      );
    });

    test('match by their contact channels', () {
      expect(
        searchContacts(<ContactSearchArea>[
          _area(generalEmail: 'kontakt@example.org'),
        ], 'kontakt@'),
        hasLength(1),
      );
      expect(
        searchContacts(<ContactSearchArea>[
          _area(phone: '+49 3496 12345'),
        ], '3496'),
        hasLength(1),
      );
      expect(
        searchContacts(<ContactSearchArea>[
          _area(website: 'https://example.org/ssc'),
        ], 'example.org'),
        hasLength(1),
      );
      expect(
        searchContacts(<ContactSearchArea>[
          _area(appointmentBookingUrl: 'https://example.org/termin'),
        ], 'termin'),
        hasLength(1),
      );
      expect(
        searchContacts(<ContactSearchArea>[
          _area(address: 'Musterweg 1'),
        ], 'musterweg'),
        hasLength(1),
      );
    });

    test('match by room number, room name, building and floor', () {
      final List<ContactSearchArea> index = <ContactSearchArea>[
        _area(rooms: <SearchRoom>[_b201]),
      ];

      expect(searchContacts(index, 'B.201'), hasLength(1));
      expect(searchContacts(index, 'Beratungsraum'), hasLength(1));
      expect(searchContacts(index, '23'), hasLength(1));
      expect(searchContacts(index, 'Testgebäude'), hasLength(1));
      expect(searchContacts(index, 'Obergeschoss'), hasLength(1));
    });
  });

  group('persons', () {
    test('are their own result, with the area they belong to', () {
      final List<ContactSearchHit> hits = searchContacts(<ContactSearchArea>[
        _area(
          name: 'Studierendenservice',
          persons: <ContactSearchPerson>[_person(name: 'Demo Person')],
        ),
      ], 'demo person');

      expect(hits, hasLength(1));
      final ContactSearchHit hit = hits.single;
      expect(hit, isA<PersonHit>());
      expect((hit as PersonHit).area.name, 'Studierendenservice');
      expect(hit.person.name, 'Demo Person');
    });

    test('match by role, description and contact channels', () {
      List<ContactSearchHit> search(ContactSearchPerson person, String term) =>
          searchContacts(<ContactSearchArea>[
            _area(persons: <ContactSearchPerson>[person]),
          ], term);

      expect(
        search(_person(role: 'Fachschaftsrat'), 'fachschaft'),
        hasLength(1),
      );
      expect(
        search(_person(description: 'Zuständig für Anträge'), 'anträge'),
        hasLength(1),
      );
      expect(
        search(_person(email: 'person@example.org'), 'person@'),
        hasLength(1),
      );
      expect(search(_person(phone: '+49 111 222'), '111'), hasLength(1));
      expect(
        search(_person(website: 'https://example.org/p'), 'example.org'),
        hasLength(1),
      );
    });

    test('match by their own room', () {
      final List<ContactSearchHit> hits = searchContacts(<ContactSearchArea>[
        _area(
          persons: <ContactSearchPerson>[
            _person(rooms: <SearchRoom>[_b201]),
          ],
        ),
      ], 'B201');

      expect(hits.single, isA<PersonHit>());
    });

    test('a matching area does not drag in its non-matching persons', () {
      final List<ContactSearchHit> hits = searchContacts(<ContactSearchArea>[
        _area(
          name: 'Prüfungsamt',
          persons: <ContactSearchPerson>[_person(name: 'Demo Person')],
        ),
      ], 'prüfungsamt');

      expect(hits, hasLength(1));
      expect(hits.single, isA<AreaHit>());
    });

    test('an area matching AND a person matching are two results', () {
      final List<ContactSearchHit> hits = searchContacts(<ContactSearchArea>[
        _area(
          name: 'Beratung',
          persons: <ContactSearchPerson>[_person(name: 'Beratungsperson')],
        ),
      ], 'beratung');

      expect(hits, hasLength(2));
      expect(hits.first, isA<AreaHit>(), reason: 'the area leads its persons');
    });
  });

  group('normalisation', () {
    test('ignores case, umlauts and diacritics', () {
      final List<ContactSearchArea> index = <ContactSearchArea>[
        _area(name: 'Prüfungsamt'),
      ];

      expect(searchContacts(index, 'PRÜFUNGSAMT'), hasLength(1));
      expect(searchContacts(index, 'pruefungsamt'), hasLength(1));
      expect(searchContacts(index, 'prufungsamt'), hasLength(1));
    });

    test('finds a room whichever way the number is written', () {
      // "B.201", "B 201" and "b201" are the same room to everybody but a
      // string comparison.
      final List<ContactSearchArea> index = <ContactSearchArea>[
        _area(rooms: <SearchRoom>[_b201]),
      ];

      expect(searchContacts(index, 'B.201'), hasLength(1));
      expect(searchContacts(index, 'B 201'), hasLength(1));
      expect(searchContacts(index, 'b201'), hasLength(1));
      expect(searchContacts(index, 'B-201'), hasLength(1));
    });

    test('does not match a different room', () {
      final List<ContactSearchArea> index = <ContactSearchArea>[
        _area(rooms: <SearchRoom>[_b201]),
      ];
      expect(searchContacts(index, 'B.202'), isEmpty);
    });
  });

  test('every hit knows why it matched', () {
    // The result list shows the matching line, so a hit on a phone number does
    // not look like an unexplained entry.
    final List<ContactSearchHit> hits = searchContacts(<ContactSearchArea>[
      _area(name: 'Studierendenservice', phone: '+49 3496 12345'),
    ], '3496');

    expect(hits.single.context, contains('3496'));
  });

  test('an area is listed once however many fields match', () {
    final List<ContactSearchHit> hits = searchContacts(<ContactSearchArea>[
      _area(
        name: 'Beratung',
        shortDescription: 'Beratung',
        descriptionText: 'Beratung',
      ),
    ], 'beratung');

    expect(hits, hasLength(1));
  });
}
