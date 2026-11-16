import 'package:campus_koethen/core/cache/content_cache.dart';
import 'package:campus_koethen/features/calendar/data/public_calendars_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import '../../support/fake_http_adapter.dart';

void main() {
  test(
    'calendar requests respect even a server configured for one calendar per request',
    () async {
      final adapter = FakeHttpAdapter((options) {
        final slugs = options.queryParameters['calendar'] as List;
        if (slugs.length > 1) {
          return const FakeHttpResponse({}, statusCode: 400);
        }
        return FakeHttpResponse(
          envelope(
            [
              {
                'id': 'demo-${slugs.single}',
                'calendarId': 'demo',
                'calendarSlug': slugs.single,
                'title': 'Demo event',
                'start': '2026-11-16T10:00:00Z',
                'end': '2026-11-16T11:00:00Z',
              },
            ],
            meta: {
              'from': '2026-11-16',
              'to': '2026-11-17',
              'truncated': slugs.single == 'demo-a',
            },
          ),
        );
      });
      final repository = PublicCalendarsRepository(
        client: fakeApiClient(adapter),
        cache: SafeContentCache(MemoryContentCache()),
      );
      final result = await repository.fetchEvents(
        locale: 'de',
        slugs: ['demo-a', 'demo-b'],
        from: '2026-11-16',
        to: '2026-11-17',
      );
      expect(result.value, hasLength(2));
      expect(result.meta.truncated, isTrue);
      expect(adapter.requests, hasLength(2));
    },
  );
}
