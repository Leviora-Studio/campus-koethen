// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:meta/meta.dart';

import '../../contacts/data/contact_search_models.dart';
import '../../contacts/domain/contact_search.dart';
import '../domain/room.dart';
import '../domain/room_number.dart';

export '../domain/room_number.dart' show normalizeRoomQuery;

/// Local search over the room catalogue.
///
/// The catalogue is small and fully cached, so searching happens on the device
/// — no request per keystroke, and it keeps working offline. The same is true
/// of the contact index it can search alongside: loaded once, folded into a
/// lookup, then used from memory.

/// Why a room is in the results, best first.
///
/// The order is the ranking: an exact room number always beats a fragment of
/// one, and a room found only through the person sitting in it comes last —
/// it is the least direct answer to what was typed.
enum RoomMatchReason {
  exactNumber,
  numberPrefix,
  numberContains,
  displayName,
  location,
  contact,
}

/// One search result: the room, and what made it match.
///
/// A record rather than a bare [Room] because "why is this here" is part of
/// the answer — a room found through a person is only understandable when the
/// person is named next to it.
@immutable
class RoomSearchHit {
  const RoomSearchHit({required this.room, required this.reason, this.context});

  final Room room;
  final RoomMatchReason reason;

  /// The matched person and their area, e.g. `Max Mustermann · Prüfungsamt`.
  /// `null` for every reason that speaks for itself.
  final String? context;

  bool get isContactMatch => reason == RoomMatchReason.contact;
}

/// Which rooms a person or an area occupies, and under whose name.
///
/// Built once from the contact index — searching the raw index per keystroke
/// would walk every area, every person and every description again for each
/// letter typed.
@immutable
class ContactRoomIndex {
  const ContactRoomIndex(this._entries);

  const ContactRoomIndex.empty() : _entries = const <_ContactRoomEntry>[];

  final List<_ContactRoomEntry> _entries;

  bool get isEmpty => _entries.isEmpty;

  /// Folds the public contact index into one flat list of room references.
  ///
  /// Only fields the index already delivers publicly are searchable: nothing
  /// here reaches for data the endpoint deliberately leaves out.
  static ContactRoomIndex fromAreas(Iterable<ContactSearchArea> areas) {
    final List<_ContactRoomEntry> entries = <_ContactRoomEntry>[];

    for (final ContactSearchArea area in areas) {
      final List<String> areaTerms = <String>[
        area.name,
        area.shortDescription,
        area.descriptionText,
      ];

      for (final SearchRoom room in area.rooms) {
        entries.add(
          _ContactRoomEntry(
            roomKey: room.roomKey,
            label: area.name,
            terms: <String>[
              ...areaTerms,
              room.roomNumber,
              room.displayName ?? '',
            ],
          ),
        );
      }

      for (final ContactSearchPerson person in area.persons) {
        for (final SearchRoom room in person.rooms) {
          entries.add(
            _ContactRoomEntry(
              roomKey: room.roomKey,
              // "Max Mustermann · Prüfungsamt": the person and where they sit.
              label: '${person.name} · ${area.name}',
              terms: <String>[
                person.name,
                person.role ?? '',
                person.description ?? '',
                area.name,
                room.roomNumber,
                room.displayName ?? '',
              ],
            ),
          );
        }
      }
    }

    return ContactRoomIndex(List<_ContactRoomEntry>.unmodifiable(entries));
  }

  /// The first matching label per room key.
  ///
  /// One entry per room even when several people match — the result list is
  /// about rooms, and the same room three times is noise, not information.
  ///
  /// The entries carry their folded forms from [fromAreas] on, so a keystroke
  /// only compares — it does not fold every name, role and description of the
  /// contact index all over again.
  Map<String, String> labelsFor(String query) {
    if (_entries.isEmpty || query.trim().isEmpty) {
      return const <String, String>{};
    }
    final ContactTerm needle = ContactTerm(query);
    if (needle.isEmpty) return const <String, String>{};

    final Map<String, String> byRoom = <String, String>{};
    for (final _ContactRoomEntry entry in _entries) {
      if (byRoom.containsKey(entry.roomKey)) continue;
      if (entry.matches(needle)) byRoom[entry.roomKey] = entry.label;
    }
    return byRoom;
  }
}

/// One room reference of the contact index, with its searchable text already
/// folded both ways.
///
/// Folding is the expensive half of a match and the text never changes for a
/// given entry, so it happens once when the index is built rather than once
/// per entry per keystroke.
@immutable
class _ContactRoomEntry {
  _ContactRoomEntry({
    required this.roomKey,
    required this.label,
    required List<String> terms,
  }) : _expanded = <String>[
         for (final String term in terms)
           if (term.isNotEmpty) normaliseContactTerm(term),
       ],
       _plain = <String>[
         for (final String term in terms)
           if (term.isNotEmpty)
             normaliseContactTerm(term, expandUmlauts: false),
       ];

  final String roomKey;
  final String label;

  /// The same terms, folded the two ways [ContactTerm] compares against. Kept
  /// as separate entries rather than joined, so a query can never match by
  /// spanning the end of one term and the start of the next.
  final List<String> _expanded;
  final List<String> _plain;

  bool matches(ContactTerm needle) {
    for (int i = 0; i < _expanded.length; i++) {
      if (_expanded[i].contains(needle.expanded) ||
          _plain[i].contains(needle.plain)) {
        return true;
      }
    }
    return false;
  }
}

/// A room's searchable text, folded once.
///
/// [searchRoomHits] runs on every keystroke and used to re-fold the number,
/// the display name and the building/floor line of EVERY room each time. The
/// values belong to the room and never change, so they are computed once per
/// [Room] instance — the same approach the contact search already takes.
@immutable
class _IndexedRoom {
  _IndexedRoom(Room room)
    : numbers = roomNumberAliases(room.roomNumber),
      // Typing just the digits is the everyday case — a timetable says "202",
      // the sign on the door says "B.202".
      bareNumbers = roomNumberAliases(
        room.roomNumber,
      ).map(bareRoomNumber).where((number) => number.isNotEmpty).toSet(),
      displayName = normalizeRoomQuery(room.displayName ?? ''),
      location = normalizeRoomQuery(
        '${room.buildingNumber} ${room.buildingName} ${room.floorName}',
      );

  final Set<String> numbers;
  final Set<String> bareNumbers;
  final String displayName;
  final String location;
}

/// Cache for [_IndexedRoom], keyed by the room instance itself.
///
/// The catalogue is loaded once and reused unchanged across a search session,
/// so the same [Room] objects come back on every keystroke. A fresh load
/// creates new instances, which get their own entries.
final Expando<_IndexedRoom> _indexedRooms = Expando<_IndexedRoom>(
  'roomSearchIndexedRoom',
);

_IndexedRoom _indexed(Room room) => _indexedRooms[room] ??= _IndexedRoom(room);

RoomMatchReason? _reasonFor(Room room, String query) {
  final _IndexedRoom folded = _indexed(room);

  // An exact room number always beats a fragment of one; otherwise "21" would
  // rank B.210 above B.21.
  if (folded.numbers.contains(query) || folded.bareNumbers.contains(query)) {
    return RoomMatchReason.exactNumber;
  }
  if (folded.numbers.any((number) => number.startsWith(query)) ||
      folded.bareNumbers.any((number) => number.startsWith(query))) {
    return RoomMatchReason.numberPrefix;
  }
  if (folded.numbers.any((number) => number.contains(query))) {
    return RoomMatchReason.numberContains;
  }

  if (folded.displayName.isNotEmpty && folded.displayName.contains(query)) {
    return RoomMatchReason.displayName;
  }

  if (folded.location.contains(query)) return RoomMatchReason.location;

  return null;
}

/// Matches either one continuous room term or several terms that all describe
/// the same room.
///
/// Trying the folded full query first preserves established room-number forms
/// such as `B 202`. Only when that does not match do whitespace-separated
/// terms become an AND query, so `216 Ratke` and `Ratke 216` both narrow an
/// otherwise ambiguous room number to one building.
RoomMatchReason? _reasonForQuery(Room room, String rawQuery) {
  final RoomMatchReason? full = _reasonFor(room, normalizeRoomQuery(rawQuery));
  if (full != null) return full;

  final List<String> terms = rawQuery
      .trim()
      .split(RegExp(r'\s+'))
      .map(normalizeRoomQuery)
      .where((String term) => term.isNotEmpty)
      .toList(growable: false);
  if (terms.length < 2) return null;

  RoomMatchReason? bestReason;
  for (final String term in terms) {
    final RoomMatchReason? reason = _reasonFor(room, term);
    if (reason == null) return null;
    if (bestReason == null || reason.index < bestReason.index) {
      bestReason = reason;
    }
  }
  return bestReason;
}

/// The catalogue in its canonical order, sorted once per list instance.
///
/// The unsorted catalogue arrives from the same provider on every keystroke,
/// so copying and re-sorting it before filtering was work repeated for every
/// letter typed.
final Expando<List<Room>> _sortedCatalogues = Expando<List<Room>>(
  'roomSearchSortedCatalogue',
);

List<Room> _canonicallySorted(Iterable<Room> rooms) {
  if (rooms is! List<Room>) {
    return rooms.toList()..sort(Room.compare);
  }
  return _sortedCatalogues[rooms] ??= List<Room>.unmodifiable(
    rooms.toList()..sort(Room.compare),
  );
}

/// Returns the matching rooms with their reason, best match first.
///
/// An empty query returns the whole catalogue in its canonical order — that is
/// the normal browsing case, not "no filter applied".
///
/// [contacts] is optional and additive: while the index is loading, or if it
/// failed, the room search behaves exactly as it does without it. A room found
/// both directly and through a person keeps its **direct** reason, which is
/// the more specific answer.
List<RoomSearchHit> searchRoomHits(
  Iterable<Room> rooms,
  String query, {
  ContactRoomIndex contacts = const ContactRoomIndex.empty(),
}) {
  final String normalised = normalizeRoomQuery(query);
  final List<Room> all = _canonicallySorted(rooms);

  if (normalised.isEmpty) {
    return <RoomSearchHit>[
      for (final Room room in all)
        RoomSearchHit(room: room, reason: RoomMatchReason.exactNumber),
    ];
  }

  final Map<String, String> contactLabels = contacts.labelsFor(query);

  final List<RoomSearchHit> matches = <RoomSearchHit>[];
  for (final Room room in all) {
    final RoomMatchReason? direct = _reasonForQuery(room, query);
    if (direct != null) {
      matches.add(RoomSearchHit(room: room, reason: direct));
      continue;
    }
    final String? label = contactLabels[room.roomKey];
    if (label != null) {
      matches.add(
        RoomSearchHit(
          room: room,
          reason: RoomMatchReason.contact,
          context: label,
        ),
      );
    }
  }

  matches.sort((RoomSearchHit a, RoomSearchHit b) {
    final int byReason = a.reason.index.compareTo(b.reason.index);
    return byReason != 0 ? byReason : Room.compare(a.room, b.room);
  });

  return matches;
}

/// Rooms only, for callers that do not care why something matched.
List<Room> searchRooms(
  Iterable<Room> rooms,
  String query, {
  ContactRoomIndex contacts = const ContactRoomIndex.empty(),
}) => searchRoomHits(
  rooms,
  query,
  contacts: contacts,
).map((RoomSearchHit hit) => hit.room).toList();
