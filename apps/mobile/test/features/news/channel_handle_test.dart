// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:campus_koethen/features/news/domain/channel_handle.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('one handle', () {
    test('the two documented examples', () {
      expect(channelHandle('FB5-News'), '@fb5-news');
      expect(channelHandle('FSR INS'), '@fsrins');
    });

    test('names are lower-cased', () {
      expect(channelHandle('CAMPUS'), '@campus');
    });

    test('spaces are removed, not turned into hyphens', () {
      // "FSR INS" is one word in a handle, not two joined by a dash.
      expect(channelHandle('Fach schaft  Rat'), '@fachschaftrat');
    });

    test('existing hyphens survive', () {
      expect(channelHandle('Campus-News-Team'), '@campus-news-team');
    });

    test('umlauts are spelled out', () {
      expect(channelHandle('Küche'), '@kueche');
      expect(channelHandle('Öffentlich'), '@oeffentlich');
      expect(channelHandle('Ähnlich'), '@aehnlich');
      expect(channelHandle('Straße'), '@strasse');
    });

    test('other diacritics fold to their base letter', () {
      expect(channelHandle('Café'), '@cafe');
      expect(channelHandle('Señor'), '@senor');
    });

    test('anything else is dropped', () {
      expect(channelHandle('News & Infos!'), '@newsinfos');
      expect(channelHandle('FB5 (offiziell)'), '@fb5offiziell');
      expect(channelHandle('#hashtag'), '@hashtag');
    });

    test('digits are kept', () {
      expect(channelHandle('FB5 2026'), '@fb52026');
    });

    test('runs of hyphens collapse and edges are trimmed', () {
      expect(channelHandle('– News –'), '@news');
      expect(channelHandle('--News--'), '@news');
      expect(channelHandle('A--B'), '@a-b');
    });

    test('a name with nothing usable yields null, not a bare sigil', () {
      // "@" alone says less than showing no handle at all.
      expect(channelHandle('!!!'), isNull);
      expect(channelHandle(''), isNull);
      expect(channelHandle('   '), isNull);
      expect(channelHandle('---'), isNull);
    });
  });

  group('an article’s handles', () {
    test('all channels are shown, in order', () {
      expect(channelHandles(<String>['FB5-News', 'FSR INS']), <String>[
        '@fb5-news',
        '@fsrins',
      ]);
    });

    test('a repeat appears once — one article, not one per channel', () {
      expect(
        channelHandles(<String>['FB5 News', 'FB5-News', 'fb5news']),
        <String>['@fb5news', '@fb5-news'],
      );
    });

    test('unusable names are skipped rather than emitted empty', () {
      expect(channelHandles(<String>['!!!', 'Campus']), <String>['@campus']);
    });

    test('no channels means no handles', () {
      expect(channelHandles(const <String>[]), isEmpty);
    });
  });
}
