// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:meta/meta.dart';

import 'room.dart';
import 'room_number.dart';

/// Turning a room *mentioned in text* into a room *on the map*.
///
/// The one place in the app that answers "does this string mean that room".
/// Timetable entries, calendar entries and contact details all ask here, so
/// there is one rule to reason about instead of one per screen.
///
/// The rule is deliberately conservative. A room link is an instruction — tap
/// this and you will stand in front of the right door — and a wrong one sends
/// somebody to the wrong floor of the wrong building. Everything that is not
/// certain therefore resolves to nothing, and the text stays plain text. It is
/// far better to make somebody search than to walk them somewhere confidently
/// and wrongly.

/// How much the source can be trusted to be *naming a room*.
enum RoomMentionSource {
  /// A field that exists to hold a room: the timetable's room list, a contact's
  /// room. The whole value is a room designation, so `202` is a room number.
  designation,

  /// Prose written by a human: a public calendar's location or title. A number
  /// in there can be anything — a house number, a course number, a year — so a
  /// mention only counts when it names its building, and only then.
  freeText,
}

/// Matches something written like a room number: one or two letters, an
/// optional separator, then digits — `B.202`, `B 202`, `B202`.
///
/// The letters are required. In free text they are the only thing separating a
/// room from any other number on the line.
final RegExp _qualifiedMention = RegExp(
  r'(?<![\p{L}\p{N}])(\p{L}{1,2})[\s.\-]?(\p{N}{1,4})(?![\p{L}\p{N}])',
  unicode: true,
);

/// The room catalogue, indexed for lookups by what people write.
///
/// Built once per catalogue rather than per entry: an agenda draws dozens of
/// entries per frame, and each of them would otherwise walk every room.
@immutable
class RoomResolver {
  const RoomResolver._(this._byNumber, this._byBareNumber);

  const RoomResolver.empty()
    : _byNumber = const <String, Room>{},
      _byBareNumber = const <String, Room>{};

  /// Normalised full number (`b202`) to room. Unique by construction in a valid
  /// catalogue; a duplicate resolves to nothing rather than to a coin flip.
  final Map<String, Room> _byNumber;

  /// Number without the building letters (`202`) to room — but only where that
  /// short form belongs to exactly one room in the whole catalogue.
  final Map<String, Room> _byBareNumber;

  bool get isEmpty => _byNumber.isEmpty;

  static RoomResolver fromRooms(Iterable<Room> rooms) {
    final Map<String, Room> byNumber = <String, Room>{};
    final Set<String> ambiguousNumbers = <String>{};
    final Map<String, Room> byBare = <String, Room>{};
    final Set<String> ambiguousBare = <String>{};

    void add(
      Map<String, Room> index,
      Set<String> ambiguous,
      String number,
      Room room,
    ) {
      if (number.isEmpty) return;
      if (index.containsKey(number) && index[number]!.roomKey != room.roomKey) {
        ambiguous.add(number);
      }
      index[number] = room;
    }

    for (final Room room in rooms) {
      for (final String number in roomNumberAliases(room.roomNumber)) {
        final String bare = bareRoomNumber(number);
        if (bare == number) {
          // A number without building letters lives in the same ambiguity
          // namespace as the short form of B.202. Otherwise adding a real room
          // 202 would silently steal every unqualified mention from B.202.
          add(byBare, ambiguousBare, bare, room);
        } else {
          add(byNumber, ambiguousNumbers, number, room);
          add(byBare, ambiguousBare, bare, room);
        }
      }
    }

    for (final String key in ambiguousNumbers) {
      byNumber.remove(key);
    }
    for (final String key in ambiguousBare) {
      byBare.remove(key);
    }

    return RoomResolver._(
      Map<String, Room>.unmodifiable(byNumber),
      Map<String, Room>.unmodifiable(byBare),
    );
  }

  /// The room a field full of room designations means, or `null`.
  ///
  /// Accepts the short form (`202` for `B.202`) because the field is already
  /// known to hold a room — but still only when it is unambiguous.
  Room? resolveDesignation(String mention) {
    final String query = normalizeRoomQuery(mention);
    if (query.isEmpty) return null;
    final Room? exact = _byNumber[query];
    if (exact != null) return exact;
    return _byBareNumber[query];
  }

  /// Every room named in a line of prose, in the order they appear.
  ///
  /// Only fully qualified mentions count, and only exact ones: `B.202` resolves,
  /// `202` does not, and `B.2` does not become `B.202`. Duplicates are dropped,
  /// because a title that says a room twice still means one room.
  List<Room> findInText(String text) {
    if (text.trim().isEmpty || _byNumber.isEmpty) return const <Room>[];

    final List<Room> found = <Room>[];
    final Set<String> seen = <String>{};
    for (final RegExpMatch match in _qualifiedMention.allMatches(text)) {
      final Room? room = _byNumber[normalizeRoomQuery(match.group(0)!)];
      if (room != null && seen.add(room.roomKey)) found.add(room);
    }
    return List<Room>.unmodifiable(found);
  }

  /// What either source is allowed to resolve to.
  List<Room> resolve(String? text, RoomMentionSource source) {
    if (text == null || text.trim().isEmpty) return const <Room>[];
    return switch (source) {
      RoomMentionSource.designation => <Room>[?resolveDesignation(text)],
      RoomMentionSource.freeText => findInText(text),
    };
  }
}
