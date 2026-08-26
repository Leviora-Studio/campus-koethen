// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import '../../campusmap/domain/room.dart';
import '../../campusmap/domain/room_mention.dart';
import 'calendar_entry.dart';
import 'calendar_entry_details.dart';

/// The rooms a calendar entry may link to.
///
/// Every candidate string is handed to the resolver together with how it is
/// allowed to be read; nothing is matched here. An entry whose room is not in
/// the catalogue, or whose text is too vague to be sure, simply gets no room —
/// the text is still readable wherever the entry is shown.
///
/// This used to live inside the detail sheet, which is why the way from an
/// entry to its room used to start with opening that sheet. It is a property of
/// the entry, not of one screen, so the agenda row can now offer the room
/// directly: tapping a lecture's room in the list opens the plan on it.
/// Whether [entry] carries anything a room could be resolved from.
///
/// Checked **before** the resolver is read, and that ordering is the point: the
/// resolver hangs off the room index, so asking it about an entry that names no
/// room at all would subscribe every agenda row to a request none of them need.
bool entryMayNameRoom(CalendarEntry entry) {
  final CalendarEntryDetails? details = entry.details;
  if (details == null) return false;
  return details.roomDesignations.isNotEmpty || details.roomProse.isNotEmpty;
}

List<Room> roomsForEntry(RoomResolver resolver, CalendarEntry entry) {
  final CalendarEntryDetails? details = entry.details;
  if (details == null) return const <Room>[];

  final List<Room> found = <Room>[];
  final Set<String> seen = <String>{};
  void add(Iterable<Room> rooms) {
    for (final Room room in rooms) {
      if (seen.add(room.roomKey)) found.add(room);
    }
  }

  for (final String value in details.roomDesignations) {
    add(resolver.resolve(value, RoomMentionSource.designation));
  }
  for (final String value in details.roomProse) {
    add(resolver.resolve(value, RoomMentionSource.freeText));
  }
  return found;
}
