// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

/// Dart-side hot-path baseline for the mobile client.
///
/// Scope and limits are described in `benchmark/README.md`; the short version
/// is that these are Main-Isolate CPU costs measured in the JIT VM, so the
/// relative comparison between two runs is the meaningful number, not the
/// absolute millisecond.
///
/// Payload sizes are not invented: they are the response sizes the Campus API
/// baseline actually produced against the `realistic` dataset profile
/// (see `docs/performance-baseline.md`), so the parsing cost measured here is
/// the cost of a real screen's data, not of an arbitrary blob.
library;

import 'dart:convert';

import 'package:campus_koethen/features/calendar/application/calendar_merge.dart';
import 'package:campus_koethen/features/calendar/domain/calendar_entry.dart';
import 'package:campus_koethen/features/calendar/domain/week_layout.dart';
import 'package:campus_koethen/features/canteen/data/canteen_models.dart';
import 'package:campus_koethen/features/news/data/news_models.dart';
import 'package:flutter_test/flutter_test.dart';

/// Deterministic PRNG, so a rerun generates byte-identical fixtures.
int _seed = 20260302;
double _random() {
  _seed = (_seed * 1103515245 + 12345) & 0x7fffffff;
  return _seed / 0x7fffffff;
}

void _resetRandom() => _seed = 20260302;

const List<String> _words = <String>[
  'Campus',
  'Studium',
  'Semester',
  'Vorlesung',
  'Bibliothek',
  'Mensa',
  'Termin',
  'Hinweis',
  'Anmeldung',
  'Prüfung',
  'Projekt',
  'Werkstatt',
];

String _sentence(int words) => List<String>.generate(
  words,
  (_) => _words[(_random() * _words.length).floor()],
).join(' ');

/// One measurement: warm up, then time [iterations] runs of [body].
///
/// The warm-up is not cosmetic — the first runs of a Dart function are
/// interpreted before the JIT promotes them, and including those would report
/// the compiler's speed rather than the code's.
_Result _measure(String name, int iterations, void Function() body) {
  for (int i = 0; i < 20; i++) {
    body();
  }
  final List<double> samples = <double>[];
  for (int i = 0; i < iterations; i++) {
    final Stopwatch sw = Stopwatch()..start();
    body();
    sw.stop();
    samples.add(sw.elapsedMicroseconds / 1000.0);
  }
  samples.sort();
  return _Result(
    name: name,
    iterations: iterations,
    p50Ms: samples[(samples.length * 0.5).floor()],
    p95Ms:
        samples[(samples.length * 0.95).floor().clamp(0, samples.length - 1)],
    maxMs: samples.last,
  );
}

class _Result {
  _Result({
    required this.name,
    required this.iterations,
    required this.p50Ms,
    required this.p95Ms,
    required this.maxMs,
  });

  final String name;
  final int iterations;
  final double p50Ms;
  final double p95Ms;
  final double maxMs;

  @override
  String toString() =>
      '${name.padRight(38)} n=$iterations  '
      'p50=${p50Ms.toStringAsFixed(3)}ms  '
      'p95=${p95Ms.toStringAsFixed(3)}ms  '
      'max=${maxMs.toStringAsFixed(3)}ms';
}

/// `GET /v1/canteens/{slug}/menu` over 14 days, 12 dishes a day.
///
/// The measured baseline response for this window is ~103 kB, which is what
/// this fixture reproduces.
String _canteenMenuJson() {
  _resetRandom();
  final List<Map<String, Object?>> days = <Map<String, Object?>>[];
  for (int d = 0; d < 14; d++) {
    final List<Map<String, Object?>> meals = <Map<String, Object?>>[];
    for (int m = 0; m < 12; m++) {
      meals.add(<String, Object?>{
        'id': 'meal-$d-$m',
        'name': _sentence(4),
        'subtitle': _random() < 0.6 ? _sentence(3) : null,
        'sourceLanguage': 'de',
        'counterId': 1 + (m % 4),
        'isSprint': m % 6 == 0,
        'extras': <String>['Dessert', 'Salat'],
        'markers': <Map<String, Object?>>[
          <String, Object?>{'code': 'A', 'label': 'Gluten', 'kind': 'allergen'},
          <String, Object?>{
            'code': 'V',
            'label': 'Vegetarisch',
            'kind': 'marker',
          },
        ],
        'traits': <String>['vegetarian'],
        'allergens': <String>['gluten'],
        'prices': <Map<String, Object?>>[
          <String, Object?>{
            'group': 'student',
            'label': 'Studierende',
            'amount': '2.90',
          },
          <String, Object?>{
            'group': 'employee',
            'label': 'Beschäftigte',
            'amount': '4.60',
          },
          <String, Object?>{
            'group': 'guest',
            'label': 'Gäste',
            'amount': '6.10',
          },
        ],
      });
    }
    days.add(<String, Object?>{
      'date': '2026-03-${(2 + d).toString().padLeft(2, '0')}',
      'meals': meals,
    });
  }
  return jsonEncode(<String, Object?>{
    'canteen': <String, Object?>{
      'slug': 'perf-canteen-1',
      'displayName': 'Perf-Mensa 1',
      'campusLabel': 'Perf-Campus 1',
    },
    'days': days,
  });
}

/// `GET /v1/posts?pageSize=20`, each post carrying its full block content.
/// The measured baseline response is ~125 kB.
String _newsPageJson() {
  _resetRandom();
  final List<Map<String, Object?>> articles = <Map<String, Object?>>[];
  for (int i = 0; i < 20; i++) {
    final List<Map<String, Object?>> content = <Map<String, Object?>>[];
    for (int b = 0; b < 14; b++) {
      if (b % 5 == 0) {
        content.add(<String, Object?>{
          'type': 'heading',
          'level': 2,
          'children': <Map<String, Object?>>[
            <String, Object?>{'type': 'text', 'text': _sentence(4)},
          ],
        });
      } else {
        content.add(<String, Object?>{
          'type': 'paragraph',
          'children': <Map<String, Object?>>[
            <String, Object?>{'type': 'text', 'text': _sentence(22)},
            <String, Object?>{
              'type': 'link',
              'url': 'https://example.invalid/quelle',
              'children': <Map<String, Object?>>[
                <String, Object?>{'type': 'text', 'text': 'Quelle'},
              ],
            },
          ],
        });
      }
    }
    articles.add(<String, Object?>{
      'slug': 'perf-post-$i',
      'title': 'Perf-Beitrag $i: ${_sentence(5)}',
      'teaser': _sentence(26),
      'publishedAt':
          '2026-02-${(1 + i % 28).toString().padLeft(2, '0')}T08:00:00.000Z',
      'isPinned': i % 40 == 0,
      'heroImage': <String, Object?>{
        'url': 'https://example.invalid/uploads/hero-$i.jpg',
        'alternativeText': 'Synthetisches Titelbild',
        'width': 1600,
        'height': 900,
      },
      'tag': <String, Object?>{
        'slug': 'perf-tag-${i % 24}',
        'name': 'Perf-Tag ${i % 24}',
        'iconKey': 'tag',
        'colorHex': '#3366CC',
      },
      'primaryChannel': <String, Object?>{
        'slug': 'perf-channel-${i % 8}',
        'name': 'Perf-Kanal ${i % 8}',
        'colorHex': '#5B3FD0',
      },
      'channels': <Map<String, Object?>>[
        <String, Object?>{
          'slug': 'perf-channel-${i % 8}',
          'name': 'Perf-Kanal ${i % 8}',
          'colorHex': '#5B3FD0',
        },
      ],
      'sourceName': 'Synthetische Quelle',
      'sourceUrl': 'https://example.invalid/quelle',
      'content': content,
    });
  }
  return jsonEncode(articles);
}

/// A semester of merged calendar entries across all three local sources.
///
/// 150 days x ~13 entries is what a student with a full timetable, Moodle
/// deadlines and a handful of subscribed public calendars actually holds — the
/// list the calendar screen re-reads on every rebuild.
List<CalendarEntry> _calendarEntries(int count) {
  _resetRandom();
  final DateTime base = DateTime(2026, 3, 2, 8);
  return List<CalendarEntry>.generate(count, (int i) {
    final DateTime start = base.add(
      Duration(days: i ~/ 13, hours: (i % 13) + (i % 3)),
    );
    // A few entries span days — an examination period or a lecture-free week.
    final bool spanning = i % 97 == 0;
    return CalendarEntry(
      id: 'entry-$i',
      source: CalendarSource.values[i % CalendarSource.values.length],
      title: _sentence(4),
      start: start,
      end: start.add(Duration(minutes: spanning ? 60 * 24 * 5 : 90)),
      subtitle: _sentence(3),
      location: 'Raum ${100 + (i % 60)}',
      isCancelled: i % 23 == 0,
      calendarSlug: 'perf-calendar-${i % 12}',
      sourceLabel: 'Perf-Quelle ${i % 12}',
      colorArgb: 0xFF3366CC,
    );
  });
}

/// Isolates WHY `WeekLayout.placeDay` costs what it costs.
///
/// This probe derives each entry's minutes ONCE — which is what the original
/// `placeDay` failed to do, asking again from the clustering loop, the greedy
/// lane assignment and the `PlacedEntry` construction. Written as a diagnostic
/// (LEVIORA-182), it was 65 % faster than production and made the case that
/// the repeated conversion, not the algorithm, was the cost.
///
/// It has since been overtaken (LEVIORA-183): `placeDay` now also decides
/// "does this end on a later day?" by comparing year, month and day as
/// numbers, while the probe below still builds the two midnight `DateTime`s.
/// Constructing a local `DateTime` costs microseconds — it resolves the zone
/// offset backwards — so those two allocations, not the component getters,
/// turned out to dominate both versions. Production is now an order of
/// magnitude below this probe, and the gap is exactly what those two
/// allocations cost.
///
/// Kept, deliberately, for two reasons: it is the reference the documented
/// baseline was taken against, so the numbers stay comparable, and the lane
/// equality asserted at the end of the week-grid test makes it a second,
/// independent oracle for the optimised implementation.
List<int> _placeDayPrecomputed(List<CalendarEntry> entries) {
  final List<CalendarEntry> timed =
      entries.where((CalendarEntry e) => !e.allDay).toList()
        ..sort((CalendarEntry a, CalendarEntry b) {
          final int byStart = a.start.compareTo(b.start);
          return byStart != 0 ? byStart : a.id.compareTo(b.id);
        });
  if (timed.isEmpty) return const <int>[];

  final int n = timed.length;
  final List<int> starts = List<int>.filled(n, 0);
  final List<int> ends = List<int>.filled(n, 0);
  for (int i = 0; i < n; i++) {
    final CalendarEntry e = timed[i];
    final DateTime start = e.start.toLocal();
    final DateTime end = (e.end ?? e.start).toLocal();
    final int startMinute = start.hour * 60 + start.minute;
    final bool endsLater = DateTime(
      end.year,
      end.month,
      end.day,
    ).isAfter(DateTime(start.year, start.month, start.day));
    final int rawEnd = endsLater
        ? WeekLayout.minutesPerDay
        : (end.hour * 60 + end.minute).clamp(0, WeekLayout.minutesPerDay);
    final int minEnd = startMinute + WeekLayout.minimumVisibleMinutes;
    starts[i] = startMinute;
    ends[i] = rawEnd < minEnd ? minEnd : rawEnd;
  }

  final List<int> lanes = List<int>.filled(n, 0);
  final List<int> laneEnds = <int>[];
  int clusterStart = 0;
  int clusterEnd = -1;

  void flush(int endExclusive) {
    laneEnds.clear();
    for (int i = clusterStart; i < endExclusive; i++) {
      int lane = -1;
      for (int l = 0; l < laneEnds.length; l++) {
        if (laneEnds[l] <= starts[i]) {
          lane = l;
          break;
        }
      }
      if (lane == -1) {
        laneEnds.add(ends[i]);
        lane = laneEnds.length - 1;
      } else {
        laneEnds[lane] = ends[i];
      }
      lanes[i] = lane;
    }
  }

  for (int i = 0; i < n; i++) {
    if (i > clusterStart && starts[i] >= clusterEnd) {
      flush(i);
      clusterStart = i;
      clusterEnd = -1;
    }
    if (ends[i] > clusterEnd) clusterEnd = ends[i];
  }
  flush(n);
  return lanes;
}

void main() {
  final List<_Result> results = <_Result>[];

  test('canteen menu parsing (14 days, 168 meals)', () {
    final String json = _canteenMenuJson();
    // ignore: avoid_print
    print('  fixture bytes: ${json.length}');
    results.add(
      _measure('canteen-menu-14d-parse', 200, () {
        final CanteenMenu? menu = CanteenMenu.fromJson(jsonDecode(json));
        expect(menu, isNotNull);
      }),
    );
  });

  test('news page parsing (20 articles with block content)', () {
    final String json = _newsPageJson();
    // ignore: avoid_print
    print('  fixture bytes: ${json.length}');
    results.add(
      _measure('news-page-20-parse', 200, () {
        final List<NewsArticle> articles = NewsArticle.listFromJson(
          jsonDecode(json),
        );
        expect(articles, hasLength(20));
      }),
    );
  });

  test('calendar merge (2000 entries)', () {
    final List<CalendarEntry> entries = _calendarEntries(2000);
    results.add(
      _measure('calendar-merge-2000', 200, () {
        final List<CalendarEntry> merged = mergeCalendarEntries(entries);
        expect(merged, hasLength(2000));
      }),
    );
  });

  test('day lookup: linear walk vs index', () {
    final List<CalendarEntry> merged = mergeCalendarEntries(
      _calendarEntries(2000),
    );
    final DateTime day = DateTime(2026, 4, 15);

    // The list walk the calendar used to do on every rebuild.
    results.add(
      _measure('calendar-entriesForDay-linear', 500, () {
        entriesForDay(merged, day);
      }),
    );

    // Building the index once is the cost the screen pays when data changes.
    results.add(
      _measure('calendar-dayIndex-build-2000', 200, () {
        CalendarDayIndex.of(merged);
      }),
    );

    // Reading one day out of the built index is the per-rebuild cost.
    final CalendarDayIndex index = CalendarDayIndex.of(merged);
    results.add(
      _measure('calendar-dayIndex-forDay', 500, () {
        index.forDay(day);
      }),
    );
  });

  test('week grid layout (7 days, overlapping entries)', () {
    final List<CalendarEntry> entries = _calendarEntries(2000);
    final DateTime monday = DateTime(2026, 3, 2);
    final List<List<CalendarEntry>> week = List<List<CalendarEntry>>.generate(
      7,
      (int d) => entriesForDay(entries, monday.add(Duration(days: d))),
    );
    results.add(
      _measure('week-layout-placeDay-x7', 500, () {
        for (final List<CalendarEntry> day in week) {
          WeekLayout.placeDay(day);
        }
      }),
    );

    // Same algorithm and the same once-per-entry minute values, but still
    // building two midnight `DateTime`s per entry. The difference to the run
    // above is what that construction costs.
    results.add(
      _measure('week-layout-precomputed-probe-x7', 500, () {
        for (final List<CalendarEntry> day in week) {
          _placeDayPrecomputed(day);
        }
      }),
    );

    // Both must place entries in the same lanes, or the probe is measuring a
    // different algorithm and its number means nothing.
    for (final List<CalendarEntry> day in week) {
      final List<int> reference = WeekLayout.placeDay(
        day,
      ).map((PlacedEntry p) => p.lane).toList();
      expect(_placeDayPrecomputed(day), reference);
    }
  });

  tearDownAll(() {
    // ignore: avoid_print
    print('\n=== mobile hot-path baseline ===');
    for (final _Result r in results) {
      // ignore: avoid_print
      print(r);
    }
  });
}
