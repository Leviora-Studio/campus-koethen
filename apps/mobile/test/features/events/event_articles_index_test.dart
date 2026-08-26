// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:campus_koethen/core/cache/cache_providers.dart';
import 'package:campus_koethen/core/cache/content_cache.dart';
import 'package:campus_koethen/core/network/network_providers.dart';
import 'package:campus_koethen/features/events/application/event_providers.dart';
import 'package:campus_koethen/features/news/data/news_models.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_http_adapter.dart';

Map<String, dynamic> _eventPost(String slug) => <String, dynamic>{
  'slug': slug,
  'title': 'Beitrag $slug',
  'publishedAt': '2026-08-01T09:00:00.000Z',
  'heroImage': null,
  'channels': <Object>[],
  'tag': <String, dynamic>{'slug': 'event', 'name': 'Event'},
  'primaryChannel': <String, dynamic>{
    'slug': 'campus-events',
    'name': 'Campus Events',
  },
  'sourceName': null,
  'sourceUrl': null,
  'content': <Object>[],
  'eventStart': '2026-08-10T18:00:00.000Z',
  'eventEnd': '2026-08-10T20:00:00.000Z',
  'eventAllDay': false,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late int postRequests;

  ProviderContainer container(List<String> slugs) {
    postRequests = 0;
    final FakeHttpAdapter adapter = FakeHttpAdapter((RequestOptions options) {
      if (options.path.contains('/posts/events')) {
        postRequests++;
        return FakeHttpResponse(
          envelope(
            <Object>[for (final String slug in slugs) _eventPost(slug)],
            meta: <String, dynamic>{
              'from': '2026-08-01',
              'to': '2026-08-31',
              'page': 1,
              'pageSize': 50,
              'pageCount': 1,
              'total': slugs.length,
            },
          ),
        );
      }
      return FakeHttpResponse(envelope(<Object>[]));
    });
    final ProviderContainer c = ProviderContainer(
      overrides: <Override>[
        contentCacheProvider.overrideWithValue(
          SafeContentCache(MemoryContentCache()),
        ),
        apiClientProvider.overrideWithValue(fakeApiClient(adapter)),
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  test('indexes the loaded event posts by slug', () async {
    final ProviderContainer c = container(<String>['sommerfest', 'sitzung']);
    c.listen(eventArticlesBySlugProvider, (_, _) {});
    await c.read(eventPostsOverviewProvider.future);

    final Map<String, NewsArticle> bySlug = c.read(eventArticlesBySlugProvider);

    expect(bySlug.keys, <String>['sommerfest', 'sitzung']);
    expect(bySlug['sitzung']!.title, 'Beitrag sitzung');
    expect(bySlug['unbekannt'], isNull);
    expect(postRequests, 1);
  });

  test('the index is built once, not per reader and not per read', () async {
    // Both halves of the event screen ask for it, and each of them rebuilds
    // on every visibility boundary, filter change and saved-list change.
    final ProviderContainer c = container(<String>['sommerfest']);
    c.listen(eventArticlesBySlugProvider, (_, _) {});
    await c.read(eventPostsOverviewProvider.future);

    expect(
      identical(
        c.read(eventArticlesBySlugProvider),
        c.read(eventArticlesBySlugProvider),
      ),
      isTrue,
    );
  });

  test('before anything is loaded the index is simply empty', () {
    final ProviderContainer c = container(<String>[]);
    expect(c.read(eventArticlesBySlugProvider), isEmpty);
  });
}
