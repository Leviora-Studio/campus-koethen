// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:campus_koethen/core/content/content_block.dart';
import 'package:campus_koethen/core/network/json.dart';
import 'package:campus_koethen/core/text/html_content.dart';
import 'package:campus_koethen/features/calendar/application/calendar_merge.dart';
import 'package:campus_koethen/features/calendar/domain/calendar_entry.dart';
import 'package:campus_koethen/features/contacts/domain/contact_search.dart';
import 'package:campus_koethen/features/events/domain/event_dedup.dart';
import 'package:campus_koethen/features/events/domain/event_visibility.dart';
import 'package:campus_koethen/features/events/domain/unified_event.dart';
import 'package:campus_koethen/features/grades/data/his_in_one_html_parser.dart';
import 'package:campus_koethen/features/moodle/domain/moodle_course_search.dart';
import 'package:campus_koethen/features/news/domain/news_preview.dart';
import 'package:campus_koethen/features/timetable/data/timetable_models.dart';
import 'package:flutter_test/flutter_test.dart';

import '../features/grades/his_in_one_fixtures.dart';

void main() {
  group('Performance Optimizations', () {
    test(
      'htmlToSafeText handles plain text fast-path and HTML tags correctly',
      () {
        expect(
          htmlToSafeText('Plain text without HTML'),
          'Plain text without HTML',
        );
        expect(htmlToSafeText(''), '');
        expect(htmlToSafeText('   '), '');
        expect(
          htmlToSafeText('<p>Paragraph <b>bold</b></p>'),
          'Paragraph bold',
        );
        expect(htmlToSafeText('Rock &amp; Roll'), 'Rock & Roll');
      },
    );

    test('asJsonMap converts maps with string or dynamic keys', () {
      expect(
        asJsonMap(<String, Object?>{'a': 1, 'b': 'two'}),
        <String, Object?>{'a': 1, 'b': 'two'},
      );
      expect(asJsonMap(<dynamic, dynamic>{1: 'one'}), <String, Object?>{
        '1': 'one',
      });
      expect(asJsonMap(null), isNull);
      expect(asJsonMap('string'), isNull);
    });

    test(
      'newsPreviewText and hasUnpreviewableBlocks cache results per block list',
      () {
        final List<ContentBlock> blocks = <ContentBlock>[
          ParagraphBlock(const <InlineNode>[InlineText(text: 'Line 1')]),
          ParagraphBlock(const <InlineNode>[InlineText(text: 'Line 2')]),
        ];
        final String first = newsPreviewText(blocks);
        final String second = newsPreviewText(blocks);
        expect(identical(first, second), isTrue);
        expect(first, 'Line 1\nLine 2');

        final bool hasUnpreviewable1 = hasUnpreviewableBlocks(blocks);
        final bool hasUnpreviewable2 = hasUnpreviewableBlocks(blocks);
        expect(hasUnpreviewable1, isFalse);
        expect(hasUnpreviewable2, isFalse);
      },
    );

    test('CalendarEntry caches day and lastDay per entry', () {
      final CalendarEntry entry = CalendarEntry(
        id: 'test-1',
        title: 'Exam',
        start: DateTime.utc(2026, 6, 1, 9, 0),
        end: DateTime.utc(2026, 6, 3, 17, 0),
        allDay: true,
        source: CalendarSource.publicCalendar,
      );
      final DateTime day1 = entry.day;
      final DateTime day2 = entry.day;
      expect(identical(day1, day2), isTrue);

      final DateTime lastDay1 = entry.lastDay;
      final DateTime lastDay2 = entry.lastDay;
      expect(identical(lastDay1, lastDay2), isTrue);
      expect(entry.coversDay(day1), isTrue);
    });

    test('CalendarDayIndex caches forDay results', () {
      final CalendarEntry entry1 = CalendarEntry(
        id: 'e1',
        title: 'Entry 1',
        start: DateTime(2026, 6, 1, 10, 0),
        end: DateTime(2026, 6, 1, 11, 0),
        allDay: false,
        source: CalendarSource.timetable,
      );
      final CalendarDayIndex index = CalendarDayIndex.of(<CalendarEntry>[
        entry1,
      ]);
      final List<CalendarEntry> list1 = index.forDay(DateTime(2026, 6, 1));
      final List<CalendarEntry> list2 = index.forDay(DateTime(2026, 6, 1));
      expect(identical(list1, list2), isTrue);
      expect(list1.length, 1);
    });

    test(
      'sameStartMinute accurately compares start times without date allocation',
      () {
        final DateTime t1 = DateTime.utc(2026, 8, 24, 14, 30, 15, 123);
        final DateTime t2 = DateTime.utc(2026, 8, 24, 14, 30, 45, 999);
        final DateTime t3 = DateTime.utc(2026, 8, 24, 14, 31, 0);

        expect(sameStartMinute(t1, t2), isTrue);
        expect(sameStartMinute(t1, t3), isFalse);
      },
    );

    test('hiddenAtBoundary caches calculation on UnifiedEvent', () {
      final UnifiedEvent event = UnifiedEvent(
        eventRef: 'post:ev-1',
        kind: UnifiedEventKind.postEvent,
        title: 'Workshop',
        start: DateTime(2026, 9, 1, 10, 0),
        end: DateTime(2026, 9, 1, 12, 0),
        allDay: false,
      );
      final DateTime b1 = hiddenAtBoundary(event);
      final DateTime b2 = hiddenAtBoundary(event);
      expect(identical(b1, b2), isTrue);
      expect(b1, DateTime(2026, 9, 1, 12, 0));
    });

    test(
      'normaliseContactTerm and normaliseMoodleTerm fold case and umlauts without intermediate lowercasing',
      () {
        expect(normaliseContactTerm('PRÜFUNGSAMT'), 'pruefungsamt');
        expect(
          normaliseContactTerm('Prüfungsamt', expandUmlauts: false),
          'prufungsamt',
        );
        expect(
          normaliseContactTerm('MÜLLER-LÜDENSCHEIDT'),
          'mueller-luedenscheidt',
        );
        expect(normaliseContactTerm('Éléonore Çetin'), 'eleonore cetin');

        expect(normaliseMoodleTerm('MATHEMATIK I (FB5)'), 'mathematik i (fb5)');
        expect(
          normaliseMoodleTerm('Einführung in die Informatik'),
          'einfuehrung in die informatik',
        );
        expect(
          normaliseMoodleTerm('Straßenbau & Vermessung'),
          'strassenbau & vermessung',
        );
      },
    );

    test('TimetableGroup caches lowercased fields for search matching', () {
      const TimetableGroup group = TimetableGroup(
        id: 'g1',
        shortName: 'INF-1',
        longName: 'Informatik Bachelor 1. Semester',
        department: 'FB5',
      );
      expect(group.matches('inf'), isTrue);
      expect(group.matches('bachelor'), isTrue);
      expect(group.matches('fb5'), isTrue);
      expect(group.matches('wirtschaft'), isFalse);
    });

    test(
      'HisInOneHtmlParser correctly parses leaf rows with O(N) detection',
      () async {
        final report = await HisInOneHtmlParser.parseGradeReport(
          hisInOneExpandedTreeHtml,
        );
        expect(report.entries, hasLength(9));
        final root = report.entries.firstWhere((e) => e.path == '1');
        final leaf = report.entries.firstWhere((e) => e.path == '1.1.1');
        expect(root.isLeaf, isFalse);
        expect(leaf.isLeaf, isTrue);
      },
    );
  });
}
