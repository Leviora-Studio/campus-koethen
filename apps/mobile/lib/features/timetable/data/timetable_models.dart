// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import '../../../core/network/json.dart';

/// A study group as delivered by `GET /v1/timetable/groups`.
///
/// [id] is the **Campus UUID**. The contract guarantees that no upstream
/// identifier ever reaches the client, and the app never stores or sends one.
class TimetableGroup {
  const TimetableGroup({
    required this.id,
    required this.shortName,
    this.longName,
    this.department,
  });

  final String id;

  /// Short name coming from the source system. Never translated.
  final String shortName;

  /// Long name coming from the source system. Never translated.
  final String? longName;

  /// Department short name, e.g. `FB5`, or `null`.
  final String? department;

  /// Case-insensitive search over short name, long name and department.
  ///
  /// A blank term matches everything so the picker can show the full list.
  bool matches(String term) {
    final String needle = term.trim().toLowerCase();
    if (needle.isEmpty) return true;
    return matchesNeedle(needle);
  }

  static final Expando<String> _lowerShortCache = Expando<String>();
  static final Expando<String> _lowerLongCache = Expando<String>();
  static final Expando<String> _lowerDeptCache = Expando<String>();

  String get _lowerShort => _lowerShortCache[this] ??= shortName.toLowerCase();
  String? get _lowerLong => longName == null
      ? null
      : (_lowerLongCache[this] ??= longName!.toLowerCase());
  String? get _lowerDept => department == null
      ? null
      : (_lowerDeptCache[this] ??= department!.toLowerCase());

  /// Fast check against an already-lowercased needle without allocations.
  bool matchesNeedle(String needle) {
    if (_lowerShort.contains(needle)) return true;
    if (_lowerLong != null && _lowerLong!.contains(needle)) {
      return true;
    }
    if (_lowerDept != null && _lowerDept!.contains(needle)) {
      return true;
    }
    return false;
  }

  static TimetableGroup? fromJson(Object? json) {
    final Map<String, dynamic>? map = asJsonMap(json);
    if (map == null) return null;
    final String? id = asString(map['id']);
    if (id == null) return null;
    return TimetableGroup(
      id: id,
      shortName: asString(map['shortName']) ?? id,
      longName: asString(map['longName']),
      department: asString(map['department']),
    );
  }

  static List<TimetableGroup> listFromJson(Object? json) => asList(json)
      .map(TimetableGroup.fromJson)
      .whereType<TimetableGroup>()
      .toList(growable: false);
}

/// Normalised status of a single entry.
///
/// An unknown upstream value is mapped onto [unknown] and never breaks the
/// screen — the contract requires exactly that.
enum TimetableEntryStatus {
  regular,
  changed,
  cancelled,
  unknown;

  static TimetableEntryStatus fromWire(Object? value) =>
      switch (asString(value)) {
        'regular' => regular,
        'changed' => changed,
        'cancelled' => cancelled,
        _ => unknown,
      };

  /// Whether the state needs to be pointed out with icon *and* text.
  bool get needsAttention => this != regular;
}

/// Normalised type of a single entry. Unknown values map onto [unknown].
enum TimetableEntryType {
  regularTeaching,
  additional,
  unknown;

  static TimetableEntryType fromWire(Object? value) =>
      switch (asString(value)) {
        'regular_teaching' => regularTeaching,
        'additional' => additional,
        _ => unknown,
      };
}

/// State of the imported data set for the requested range (`meta.dataState`).
enum TimetableDataState {
  ready,
  pending,
  unavailable,
  unknown;

  /// An absent value is treated as [ready]; an unrecognised one as [unknown],
  /// which the UI renders like [ready] instead of blocking the screen.
  static TimetableDataState fromWire(Object? value) {
    final String? raw = asString(value);
    if (raw == null) return ready;
    return switch (raw) {
      'ready' => ready,
      'pending' => pending,
      'unavailable' => unavailable,
      _ => unknown,
    };
  }
}

/// A teacher of an entry. Comes from the source system and is never translated.
class TimetableTeacher {
  const TimetableTeacher({required this.shortName, this.displayName});

  final String shortName;
  final String? displayName;

  /// The name to render: the long form when it is maintained.
  String get label => displayName ?? shortName;

  static TimetableTeacher? fromJson(Object? json) {
    final Map<String, dynamic>? map = asJsonMap(json);
    if (map == null) return null;
    final String? shortName =
        asString(map['shortName']) ?? asString(map['displayName']);
    if (shortName == null) return null;
    return TimetableTeacher(
      shortName: shortName,
      displayName: asString(map['displayName']),
    );
  }
}

/// A room of an entry. Comes from the source system and is never translated.
class TimetableRoom {
  const TimetableRoom({required this.shortName, this.longName});

  final String shortName;
  final String? longName;

  String get label => shortName;

  static TimetableRoom? fromJson(Object? json) {
    final Map<String, dynamic>? map = asJsonMap(json);
    if (map == null) return null;
    final String? shortName =
        asString(map['shortName']) ?? asString(map['longName']);
    if (shortName == null) return null;
    return TimetableRoom(
      shortName: shortName,
      longName: asString(map['longName']),
    );
  }
}

/// One appointment.
///
/// [start] and [end] are absolute UTC instants. The business time zone
/// `Europe/Berlin` additionally travels in [timezone] because the source
/// delivers local wall clock time without a zone. The UI renders the device's
/// local time, which is the correct reading for users on campus.
class TimetableEntry {
  const TimetableEntry({
    required this.id,
    required this.start,
    required this.end,
    this.timezone,
    this.title,
    this.subjectCode,
    this.type = TimetableEntryType.unknown,
    this.status = TimetableEntryStatus.unknown,
    this.teachers = const <TimetableTeacher>[],
    this.rooms = const <TimetableRoom>[],
    this.groups = const <TimetableGroup>[],
    this.note,
  });

  final String id;
  final DateTime start;
  final DateTime end;
  final String? timezone;

  /// Subject title from the source system. Never translated, may be absent.
  final String? title;
  final String? subjectCode;

  final TimetableEntryType type;
  final TimetableEntryStatus status;
  final List<TimetableTeacher> teachers;
  final List<TimetableRoom> rooms;
  final List<TimetableGroup> groups;
  final String? note;

  /// Title, falling back to the subject code. `null` when neither is set — the
  /// UI then shows a localised placeholder.
  String? get displayTitle => title ?? subjectCode;

  static TimetableEntry? fromJson(Object? json) {
    final Map<String, dynamic>? map = asJsonMap(json);
    if (map == null) return null;
    final DateTime? start = asDateTime(map['start']);
    final DateTime? end = asDateTime(map['end']);
    if (start == null || end == null) return null;
    return TimetableEntry(
      id: asString(map['id']) ?? '${start.toIso8601String()}|${map['title']}',
      start: start,
      end: end,
      timezone: asString(map['timezone']),
      title: asString(map['title']),
      subjectCode: asString(map['subjectCode']),
      type: TimetableEntryType.fromWire(map['type']),
      status: TimetableEntryStatus.fromWire(map['status']),
      teachers: asList(map['teachers'])
          .map(TimetableTeacher.fromJson)
          .whereType<TimetableTeacher>()
          .toList(growable: false),
      rooms: asList(map['rooms'])
          .map(TimetableRoom.fromJson)
          .whereType<TimetableRoom>()
          .toList(growable: false),
      groups: TimetableGroup.listFromJson(map['groups']),
      note: asString(map['note']),
    );
  }
}

/// One calendar day. An empty [entries] list is a real free day — the contract
/// guarantees every day of the range is present, so it is never a load failure.
class TimetableDay {
  const TimetableDay({required this.date, required this.entries});

  final DateTime date;
  final List<TimetableEntry> entries;

  bool isSameDay(DateTime other) =>
      date.year == other.year &&
      date.month == other.month &&
      date.day == other.day;

  static TimetableDay? fromJson(Object? json) {
    final Map<String, dynamic>? map = asJsonMap(json);
    if (map == null) return null;
    final DateTime? date = asCalendarDate(map['date']);
    if (date == null) return null;
    final List<TimetableEntry> entries =
        asList(
            map['entries'],
          ).map(TimetableEntry.fromJson).whereType<TimetableEntry>().toList()
          ..sort(
            (TimetableEntry a, TimetableEntry b) => a.start.compareTo(b.start),
          );
    return TimetableDay(date: date, entries: entries);
  }
}

/// The timetable of one group over a date range.
class Timetable {
  const Timetable({required this.group, required this.days});

  final TimetableGroup group;
  final List<TimetableDay> days;

  TimetableDay? dayFor(DateTime date) {
    for (final TimetableDay day in days) {
      if (day.isSameDay(date)) return day;
    }
    return null;
  }

  static Timetable? fromJson(Object? json) {
    final Map<String, dynamic>? map = asJsonMap(json);
    if (map == null) return null;
    final TimetableGroup? group = TimetableGroup.fromJson(map['group']);
    if (group == null) return null;
    final List<TimetableDay> days =
        asList(
            map['days'],
          ).map(TimetableDay.fromJson).whereType<TimetableDay>().toList()
          ..sort((TimetableDay a, TimetableDay b) => a.date.compareTo(b.date));
    return Timetable(group: group, days: days);
  }
}
