// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:campus_koethen/core/network/api_meta.dart';
import 'package:campus_koethen/core/network/loaded.dart';
import 'package:campus_koethen/features/calendar/application/public_calendar_providers.dart';
import 'package:campus_koethen/features/calendar/domain/public_calendar.dart';
import 'package:campus_koethen/features/events/application/event_providers.dart';
import 'package:campus_koethen/features/events/data/event_posts_repository.dart';
import 'package:campus_koethen/features/events/domain/unified_event.dart';
import 'package:campus_koethen/features/news/data/news_models.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Events are offered per channel only. A public calendar without a channel —
/// still served by an older backend, or read from the cache — has no filter
/// option it could belong to and is therefore not shown at all.
///
/// All calendars and events below are fictional demo data.
void main() {
  PublicCalendar calendar(String slug, String? channelSlug) => PublicCalendar(
    id: 'id-$slug',
    slug: slug,
    channelSlug: channelSlug,
    name: 'Kalender $slug',
    colorHex: '#5B3FD0',
    sortOrder: 0,
    defaultSubscribed: true,
    googleOpenUrl: 'https://calendar.google.com/calendar/u/0',
  );

  PublicCalendarEvent event(String id, String calendarSlug) =>
      PublicCalendarEvent(
        id: id,
        calendarId: 'id-$calendarSlug',
        calendarSlug: calendarSlug,
        title: 'Demo-Termin $id',
        start: DateTime.utc(2026, 9, 2, 18),
        end: DateTime.utc(2026, 9, 2, 20),
      );

  test('events of a calendar without a channel are left out', () async {
    final ProviderContainer c = ProviderContainer(
      overrides: [
        publicCalendarsCatalogProvider.overrideWith(
          (Ref ref) async => Loaded<List<PublicCalendar>>(
            value: <PublicCalendar>[
              calendar('fsr-termine', 'fsr'),
              calendar('lose-termine', null),
            ],
            meta: ApiMeta.empty,
          ),
        ),
        eventCalendarsOverviewProvider.overrideWith(
          (Ref ref) async => Loaded<List<PublicCalendarEvent>>(
            value: <PublicCalendarEvent>[
              event('mit-kanal', 'fsr-termine'),
              event('ohne-kanal', 'lose-termine'),
            ],
            meta: ApiMeta.empty,
          ),
        ),
        eventPostsOverviewProvider.overrideWith(
          (Ref ref) async => const EventPostsResult(
            articles: <NewsArticle>[],
            isTruncated: false,
            from: null,
            to: null,
          ),
        ),
      ],
    );
    addTearDown(c.dispose);
    await c.read(publicCalendarsCatalogProvider.future);
    await c.read(eventCalendarsOverviewProvider.future);
    await c.read(eventPostsOverviewProvider.future);

    final List<UnifiedEvent> events = c.read(rawUnifiedEventsProvider);

    expect(events.map((UnifiedEvent e) => e.calendarEventId), <String>[
      'mit-kanal',
    ]);
    expect(events.single.channelSlug, 'fsr');
  });
}
