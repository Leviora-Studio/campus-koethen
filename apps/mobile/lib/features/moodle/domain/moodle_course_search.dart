// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'moodle_course.dart';

/// Folds a string down to something two spellings of the same word share.
///
/// Case, the German umlauts and the common Latin diacritics all collapse, so
/// "Prüfung", "PRUEFUNG" and "prufung" match each other. Deliberately not a
/// full Unicode normalisation: this runs on every keystroke over the whole
/// course list, and the cases below are the ones a course title actually has.
String normaliseMoodleTerm(String value) {
  final StringBuffer out = StringBuffer();
  for (final int rune in value.runes) {
    switch (rune) {
      case >= 0x41 && <= 0x5A:
        out.writeCharCode(rune + 32);
      case 0xE4 || 0xC4: // ä / Ä
        out.write('ae');
      case 0xF6 || 0xD6: // ö / Ö
        out.write('oe');
      case 0xFC || 0xDC: // ü / Ü
        out.write('ue');
      case 0xDF: // ß
        out.write('ss');
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

class _IndexedMoodleCourse {
  _IndexedMoodleCourse(MoodleCourse course)
    : fullName = normaliseMoodleTerm(course.fullName),
      shortName = normaliseMoodleTerm(course.shortName),
      summary = normaliseMoodleTerm(course.summary);

  final String fullName;
  final String shortName;
  final String summary;

  bool matches(String needle) =>
      fullName.contains(needle) ||
      shortName.contains(needle) ||
      summary.contains(needle);
}

final Expando<_IndexedMoodleCourse> _indexedCourses =
    Expando<_IndexedMoodleCourse>('moodleSearchIndexedCourse');

_IndexedMoodleCourse _indexed(MoodleCourse course) =>
    _indexedCourses[course] ??= _IndexedMoodleCourse(course);

/// Filters the already-loaded courses.
///
/// **Purely local.** The list comes from the encrypted on-device cache, and no
/// keystroke may turn into a request — neither to Moodle nor, obviously, to a
/// Campus Köthen backend, which must never see Moodle data at all.
///
/// An empty or whitespace-only term returns the list unchanged rather than
/// nothing: an empty search field is not a filter.
List<MoodleCourse> searchMoodleCourses(
  Iterable<MoodleCourse> courses,
  String term,
) {
  final String needle = normaliseMoodleTerm(term);
  if (needle.isEmpty) return courses.toList(growable: false);

  return courses
      .where((MoodleCourse course) => _indexed(course).matches(needle))
      .toList(growable: false);
}
