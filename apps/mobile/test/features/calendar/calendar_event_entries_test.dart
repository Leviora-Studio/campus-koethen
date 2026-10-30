// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:campus_koethen/core/cache/cache_providers.dart';
import 'package:campus_koethen/core/cache/content_cache.dart';
import 'package:campus_koethen/core/network/network_providers.dart';
import 'package:campus_koethen/core/prefs/key_value_store.dart';
import 'package:campus_koethen/core/prefs/settings_controller.dart';
import 'package:campus_koethen/features/calendar/application/calendar_event_providers.dart';
import 'package:campus_koethen/features/calendar/domain/calendar_entry.dart';
import 'package:campus_koethen/features/calendar/domain/calendar_entry_details.dart';
import 'package:campus_koethen/features/events/application/event_providers.dart';
import 'package:campus_koethen/features/events/application/event_source_filter.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_http_adapter.dart';

/// The calendar shows exactly what the event overview offers: the event posts
/// and public-calendar events of the channels selected in the one shared
/// event-source filter, deduplicated by the events feature's own rule.
///
/// All channels, calendars and posts below are fictional demo data.

Map<String, dynamic> _channel(String slug, String name, String color) =>
    <String, dynamic>{
      'slug': slug,
      'name': name,
      'description': null,
      'colorHex': color,
      'sortOrder': 0,
      'defaultSubscribed': true,
    };

Map<String, dynamic> _calendar(String slug, String? channelSlug) =>
    <String, dynamic>{
      'id': 'id-$slug',
      'slug': slug,
      'channelSlug': channelSlug,
      'name': 'Kalender $slug',
      'colorHex': '#C2185B',
      'sortOrder': 0,
      'defaultSubscribed': true,
      'dataStale': false,
      'googleOpenUrl': 'https://calendar.google.com/calendar/u/0',
    };

Map<String, dynamic> _post(String slug, String channel, String start) =>
    <String, dynamic>{
      'slug': slug,
      'title': 'Demo-Beitrag $slug',
      'publishedAt': '2026-05-01T09:00:00.000Z',
      'heroImage': null,
      'channels': <Object>[
        <String, dynamic>{'slug': channel, 'name': channel},
      ],
      'tag': <String, dynamic>{'slug': 'event', 'name': 'Event'},
      'primaryChannel': <String, dynamic>{
        'slug': channel,
        'name': channel == 'fsr' ? 'Demo-FSR' : 'Demo-StuRa',
        'colorHex': channel == 'fsr' ? '#C2185B' : '#1E88E5',
      },
      'content': <Object>[],
      'eventStart': start,
      'eventEnd': null,
      'eventAllDay': false,
    };

Map<String, dynamic> _calendarEvent(String id, String calendar, String start) =>
    <String, dynamic>{
      'id': id,
      'calendarId': 'id-$calendar',
      'calendarSlug': calendar,
      'title': 'Demo-Termin $id',
      'start': start,
      'end': start,
    };

void main() {
  // localeCodeProvider reads the platform locale through the binding.
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<RequestOptions> requests;

  ProviderContainer container() {
    requests = <RequestOptions>[];
    final FakeHttpAdapter adapter = FakeHttpAdapter((RequestOptions options) {
      requests.add(options);
      switch (options.path) {
        case '/posts/channels':
          return FakeHttpResponse(
            envelope(<Object>[
              _channel('fsr', 'Demo-FSR', '#C2185B'),
              _channel('stura', 'Demo-StuRa', '#1E88E5'),
            ]),
          );
        case '/calendars':
          return FakeHttpResponse(
            envelope(<Object>[
              _calendar('fsr-termine', 'fsr'),
              // An old backend may still serve a calendar without a channel.
              _calendar('lose-termine', null),
            ]),
          );
        case '/posts/events':
          return FakeHttpResponse(
            envelope(
              <Object>[
                _post('fsr-abend', 'fsr', '2026-05-10T16:00:00.000Z'),
                _post('stura-sitzung', 'stura', '2026-05-12T16:00:00.000Z'),
                _post('fsr-doppelt', 'fsr', '2026-05-14T16:00:00.000Z'),
              ],
              meta: <String, dynamic>{
                'from': options.queryParameters['from'],
                'to': options.queryParameters['to'],
              },
            ),
          );
        case '/calendars/events':
          final List<Object?> slugs =
              (options.queryParameters['calendar'] as List<Object?>?) ??
              <Object?>[];
          return FakeHttpResponse(
            envelope(<Object>[
              if (slugs.contains('fsr-termine')) ...<Object>[
                // Same channel, same minute as the post `fsr-doppelt`.
                _calendarEvent(
                  'doppelt',
                  'fsr-termine',
                  '2026-05-14T16:00:00.000Z',
                ),
                _calendarEvent(
                  'einzeln',
                  'fsr-termine',
                  '2026-05-20T16:00:00.000Z',
                ),
              ],
              if (slugs.contains('lose-termine'))
                _calendarEvent(
                  'lose',
                  'lose-termine',
                  '2026-05-21T16:00:00.000Z',
                ),
            ]),
          );
      }
      return FakeHttpResponse(envelope(<Object>[]));
    });
    final ProviderContainer c = ProviderContainer(
      overrides: <Override>[
        keyValueStoreProvider.overrideWithValue(InMemoryKeyValueStore()),
        contentCacheProvider.overrideWithValue(
          SafeContentCache(MemoryContentCache()),
        ),
        apiClientProvider.overrideWithValue(fakeApiClient(adapter)),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  Future<List<CalendarEntry>> month(ProviderContainer c) async {
    c.listen(
      calendarEventMonthEntriesProvider(DateTime(2026, 5, 4)),
      (_, _) {},
    );
    return c.read(
      calendarEventMonthEntriesProvider(DateTime(2026, 5, 4)).future,
    );
  }

  test('shows the event posts and calendar events of every selected channel, '
      'deduplicated like the event overview', () async {
    final ProviderContainer c = container();

    final List<CalendarEntry> entries = await month(c);

    expect(
      entries.map((CalendarEntry e) => e.id),
      unorderedEquals(<String>[
        'postEvent:fsr-abend',
        'postEvent:stura-sitzung',
        'postEvent:fsr-doppelt',
        'publicCalendar:fsr-termine:einzeln',
      ]),
      reason: 'the post wins over the identical calendar event',
    );

    final CalendarEntry post = entries.firstWhere(
      (CalendarEntry e) => e.id == 'postEvent:stura-sitzung',
    );
    expect(post.source, CalendarSource.postEvent);
    expect(post.colorArgb, 0xFF1E88E5, reason: "the channel's colour");
    expect(post.sourceLabel, contains('Demo-StuRa'));
    expect((post.details! as PostEventDetails).article.slug, 'stura-sitzung');
  });

  test('a channel deselected in the event filter disappears from the '
      'calendar too', () async {
    final ProviderContainer c = container();
    c.listen(eventSourceOptionsProvider, (_, _) {});
    await c.read(eventSourceOptionsProvider.future);

    await c
        .read(eventSourceFilterProvider.notifier)
        .setSelected('fsr', selected: false);
    final List<CalendarEntry> entries = await month(c);

    expect(entries.map((CalendarEntry e) => e.id), <String>[
      'postEvent:stura-sitzung',
    ]);
    expect(
      requests.where((RequestOptions r) => r.path == '/calendars/events'),
      isEmpty,
      reason: 'no selected channel has a calendar left to ask about',
    );
  });

  test('a calendar without a channel never reaches the calendar', () async {
    final ProviderContainer c = container();

    final List<CalendarEntry> entries = await month(c);

    expect(
      entries.where((CalendarEntry e) => e.calendarSlug == 'lose-termine'),
      isEmpty,
    );
  });

  test('the calendar offers the same choice as the event overview: one '
      'option per channel', () async {
    final ProviderContainer c = container();
    c.listen(eventSourceOptionsProvider, (_, _) {});

    final List<EventSourceOption> options = await c.read(
      eventSourceOptionsProvider.future,
    );

    expect(options.map((EventSourceOption o) => o.key), <String>[
      'fsr',
      'stura',
    ]);
  });
}
