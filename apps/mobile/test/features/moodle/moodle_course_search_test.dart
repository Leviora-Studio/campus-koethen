// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:campus_koethen/features/moodle/domain/moodle_course.dart';
import 'package:campus_koethen/features/moodle/domain/moodle_course_search.dart';
import 'package:flutter_test/flutter_test.dart';

const List<MoodleCourse> _courses = <MoodleCourse>[
  MoodleCourse(
    id: 1,
    fullName: 'Einführung in die Programmierung',
    shortName: 'EIP',
    summary: 'Grundlagen von Dart und Flutter.',
  ),
  MoodleCourse(
    id: 2,
    fullName: 'Rechnernetze',
    shortName: 'RN-2026',
    summary: 'Schichtenmodelle, Routing, Prüfung am Semesterende.',
  ),
  MoodleCourse(id: 3, fullName: 'Mathematik II', shortName: 'MA2', summary: ''),
];

List<int> _ids(List<MoodleCourse> courses) =>
    courses.map((MoodleCourse c) => c.id).toList();

void main() {
  group('normalising', () {
    test('case and German umlauts collapse', () {
      expect(normaliseMoodleTerm('Prüfung'), normaliseMoodleTerm('PRUEFUNG'));
      expect(normaliseMoodleTerm('Einführung'), 'einfuehrung');
      expect(normaliseMoodleTerm('Straße'), 'strasse');
    });

    test('common diacritics collapse too', () {
      expect(normaliseMoodleTerm('Café'), 'cafe');
      expect(normaliseMoodleTerm('naïve'), 'naive');
    });

    test('surrounding whitespace is ignored', () {
      expect(normaliseMoodleTerm('  Netze  '), 'netze');
    });
  });

  group('searching', () {
    test('an empty term is not a filter', () {
      expect(_ids(searchMoodleCourses(_courses, '')), <int>[1, 2, 3]);
      expect(_ids(searchMoodleCourses(_courses, '   ')), <int>[1, 2, 3]);
    });

    test('matches the full name', () {
      expect(_ids(searchMoodleCourses(_courses, 'rechner')), <int>[2]);
    });

    test('matches the short name', () {
      expect(_ids(searchMoodleCourses(_courses, 'ma2')), <int>[3]);
      expect(_ids(searchMoodleCourses(_courses, 'RN-2026')), <int>[2]);
    });

    test('matches the summary', () {
      expect(_ids(searchMoodleCourses(_courses, 'routing')), <int>[2]);
    });

    test('finds an umlaut course typed without one', () {
      // "Einführung" typed as "einfuehrung", and "Prüfung" as "pruefung".
      expect(_ids(searchMoodleCourses(_courses, 'einfuehrung')), <int>[1]);
      expect(_ids(searchMoodleCourses(_courses, 'pruefung')), <int>[2]);
    });

    test('finds an umlaut course typed with one', () {
      expect(_ids(searchMoodleCourses(_courses, 'Einführung')), <int>[1]);
    });

    test('no match yields an empty list, not everything', () {
      expect(searchMoodleCourses(_courses, 'quantenfeldtheorie'), isEmpty);
    });

    test('the original order is kept', () {
      expect(_ids(searchMoodleCourses(_courses, 'e')), <int>[1, 2, 3]);
    });

    test('a course with an empty summary does not crash the match', () {
      expect(_ids(searchMoodleCourses(_courses, 'mathematik')), <int>[3]);
    });
  });
}
