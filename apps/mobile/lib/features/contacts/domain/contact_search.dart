// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:flutter/foundation.dart';

import '../data/contact_search_models.dart';

/// Local search over the contact index.
///
/// **Purely local.** The index is loaded once and cached; no keystroke becomes
/// a request. That is also why the API has a dedicated index endpoint at all —
/// searching over descriptions and room numbers otherwise meant one detail
/// request per area, on every letter typed.

/// One result: either an area or a person inside one.
@immutable
sealed class ContactSearchHit {
  const ContactSearchHit({required this.area, required this.context});

  /// The area to open when the result is tapped. For a person, the area they
  /// belong to — that is where their details live.
  final ContactSearchArea area;

  /// The text that matched, shown under the result so a hit on a phone number
  /// does not look like an unexplained entry.
  final String context;
}

class AreaHit extends ContactSearchHit {
  const AreaHit({required super.area, required super.context});
}

class PersonHit extends ContactSearchHit {
  const PersonHit({
    required this.person,
    required super.area,
    required super.context,
  });

  final ContactSearchPerson person;
}

/// Folds a string down to something two spellings of the same word share.
///
/// Case and the common Latin diacritics collapse. Umlauts are the awkward
/// case: somebody looking for "Prüfungsamt" may type "pruefungsamt" or
/// "prufungsamt", and no single spelling contains both. So there are two
/// foldings — [expandUmlauts] writes `ü` as `ue`, otherwise as `u` — and a
/// match is accepted when **either** agrees. Anything else would make one of
/// the two spellings silently find nothing.
String normaliseContactTerm(String value, {bool expandUmlauts = true}) {
  final StringBuffer out = StringBuffer();
  for (final int rune in value.runes) {
    switch (rune) {
      case >= 0x41 && <= 0x5A:
        out.writeCharCode(rune + 32);
      case 0xE4 || 0xC4: // ä / Ä
        out.write(expandUmlauts ? 'ae' : 'a');
      case 0xF6 || 0xD6: // ö / Ö
        out.write(expandUmlauts ? 'oe' : 'o');
      case 0xFC || 0xDC: // ü / Ü
        out.write(expandUmlauts ? 'ue' : 'u');
      case 0xDF: // ß
        out.write(expandUmlauts ? 'ss' : 's');
      case 0xE0 ||
          0xE1 ||
          0xE2 ||
          0xE3 ||
          0xE5 ||
          0xC0 ||
          0xC1 ||
          0xC2 ||
          0xC3 ||
          0xC5:
        out.write('a');
      case 0xE8 || 0xE9 || 0xEA || 0xEB || 0xC8 || 0xC9 || 0xCA || 0xCB:
        out.write('e');
      case 0xEC || 0xED || 0xEE || 0xEF || 0xCC || 0xCD || 0xCE || 0xCF:
        out.write('i');
      case 0xF2 || 0xF3 || 0xF4 || 0xF5 || 0xD2 || 0xD3 || 0xD4 || 0xD5:
        out.write('o');
      case 0xF9 || 0xFA || 0xFB || 0xD9 || 0xDA || 0xDB:
        out.write('u');
      case 0xE7 || 0xC7: // ç / Ç
        out.write('c');
      case 0xF1 || 0xD1: // ñ / Ñ
        out.write('n');
      default:
        out.writeCharCode(rune);
    }
  }
  return out.toString().trim();
}

final RegExp _nonAlphanumeric = RegExp('[^a-z0-9]');

/// The room-number form of a term: letters and digits only.
///
/// "B.201", "B 201", "B-201" and "b201" are the same room to everybody but a
/// string comparison, and a room number is exactly the kind of thing people
/// type without its punctuation.
String _roomForm(String value) =>
    normaliseContactTerm(value).replaceAll(_nonAlphanumeric, '');

/// Both foldings of one string, so a match can accept either.
///
/// Public because the campus-map search needs exactly these rules when it
/// looks a room up through the person sitting in it — a second copy would be
/// a second answer to "does ü match ue", and the two would drift.
@immutable
class ContactTerm {
  ContactTerm(String term)
    : expanded = normaliseContactTerm(term),
      plain = normaliseContactTerm(term, expandUmlauts: false),
      room = _roomForm(term);

  final String expanded;
  final String plain;
  final String room;

  bool get isEmpty => expanded.isEmpty;

  bool matches(String haystack) =>
      normaliseContactTerm(haystack).contains(expanded) ||
      normaliseContactTerm(haystack, expandUmlauts: false).contains(plain);
}

/// A field's text alongside both foldings of it, computed once.
///
/// Kept next to the raw value so a hit can still report what actually
/// matched — the normalised form is only ever used to decide *whether*
/// something matched, never *what* is shown.
class _IndexedField {
  const _IndexedField(this.raw, this.expanded, this.plain);

  final String raw;
  final String expanded;
  final String plain;

  /// `null` for a missing or empty field, mirroring the skip the unindexed
  /// search used to do inline.
  static _IndexedField? from(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    return _IndexedField(
      raw,
      normaliseContactTerm(raw),
      normaliseContactTerm(raw, expandUmlauts: false),
    );
  }

  bool matches(ContactTerm needle) =>
      expanded.contains(needle.expanded) || plain.contains(needle.plain);
}

/// One room's fields, folded once, plus its punctuation-free room form.
class _IndexedRoom {
  _IndexedRoom(SearchRoom room)
    : roomNumberRaw = room.roomNumber,
      roomNumberForm = _roomForm(room.roomNumber),
      fields = <_IndexedField?>[
        _IndexedField.from(room.roomNumber),
        _IndexedField.from(room.displayName),
        _IndexedField.from(room.buildingNumber),
        _IndexedField.from(room.buildingName),
        _IndexedField.from(room.floorName),
      ];

  final String roomNumberRaw;
  final String roomNumberForm;
  final List<_IndexedField?> fields;
}

/// The folded fields and rooms of one area or person, built once and then
/// reused for every keystroke of a search session.
class _IndexedEntry {
  _IndexedEntry(List<String?> rawFields, List<SearchRoom> rooms)
    : fields = rawFields.map(_IndexedField.from).toList(growable: false),
      indexedRooms = rooms
          .map((SearchRoom room) => _IndexedRoom(room))
          .toList(growable: false);

  final List<_IndexedField?> fields;
  final List<_IndexedRoom> indexedRooms;
}

/// Caches for [_IndexedEntry], keyed by the area/person instance itself.
///
/// The search index is loaded once and reused unchanged across every
/// keystroke (see [contactSearchIndexProvider]), so the same
/// [ContactSearchArea]/[ContactSearchPerson] objects come back on every
/// call. Folding their fields is the expensive part of a search — the fields
/// themselves never change for a given instance, so it only ever needs to
/// happen once per instance rather than once per keystroke. A fresh load
/// (e.g. after `ref.invalidate`) creates new instances, which simply get
/// their own cache entries.
final Expando<_IndexedEntry> _areaEntryCache = Expando<_IndexedEntry>(
  'contactSearchAreaEntry',
);
final Expando<_IndexedEntry> _personEntryCache = Expando<_IndexedEntry>(
  'contactSearchPersonEntry',
);

_IndexedEntry _areaEntry(ContactSearchArea area) =>
    _areaEntryCache[area] ??= _IndexedEntry(_areaFields(area), area.rooms);

_IndexedEntry _personEntry(ContactSearchPerson person) =>
    _personEntryCache[person] ??= _IndexedEntry(
      _personFields(person),
      person.rooms,
    );

/// Searches [index] for [term].
///
/// An empty term yields **no** results rather than everything: the screen falls
/// back to the ordinary area list, and "match everything" is not what an empty
/// search field means.
///
/// An area and one of its persons can both match; they are then two results,
/// with the area first. A matching area never drags in its persons — a hit has
/// to be a hit on its own.
List<ContactSearchHit> searchContacts(
  Iterable<ContactSearchArea> index,
  String term,
) {
  final ContactTerm needle = ContactTerm(term);
  if (needle.isEmpty) return const <ContactSearchHit>[];

  final List<ContactSearchHit> hits = <ContactSearchHit>[];

  for (final ContactSearchArea area in index) {
    final String? areaMatch = _firstMatch(needle, _areaEntry(area));
    if (areaMatch != null) {
      hits.add(AreaHit(area: area, context: areaMatch));
    }

    for (final ContactSearchPerson person in area.persons) {
      final String? personMatch = _firstMatch(needle, _personEntry(person));
      if (personMatch != null) {
        hits.add(PersonHit(person: person, area: area, context: personMatch));
      }
    }
  }

  return List<ContactSearchHit>.unmodifiable(hits);
}

/// The first field that contains the term, so the result can show *why*.
String? _firstMatch(ContactTerm needle, _IndexedEntry entry) {
  for (final _IndexedField? field in entry.fields) {
    if (field != null && field.matches(needle)) return field.raw;
  }
  for (final _IndexedRoom room in entry.indexedRooms) {
    for (final _IndexedField? field in room.fields) {
      if (field != null && field.matches(needle)) return field.raw;
    }
    // The punctuation-free form only ever applies to the number itself:
    // stripping it from prose would match across word boundaries.
    if (needle.room.isNotEmpty && room.roomNumberForm.contains(needle.room)) {
      return room.roomNumberRaw;
    }
  }
  return null;
}

List<String?> _areaFields(ContactSearchArea area) => <String?>[
  area.name,
  area.shortDescription,
  area.descriptionText,
  area.generalEmail,
  area.phone,
  area.website,
  area.appointmentBookingUrl,
  area.address,
  area.openingHours,
];

List<String?> _personFields(ContactSearchPerson person) => <String?>[
  person.name,
  person.role,
  person.description,
  person.email,
  person.phone,
  person.website,
];
