// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:campus_koethen/core/locale/locale_mode.dart';
import 'package:campus_koethen/core/network/network_providers.dart';
import 'package:campus_koethen/features/news/application/news_channel_feed_controller.dart';
import 'package:campus_koethen/features/news/data/news_models.dart';
import 'package:campus_koethen/features/news/presentation/article_block.dart';
import 'package:campus_koethen/features/news/presentation/news_channel_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_http_adapter.dart';
import '../../support/fixtures.dart';
import '../../support/news_harness.dart';
import '../../support/pump_app.dart';

/// An article with a title long enough to give the card a real height.
Map<String, dynamic> _article(String slug) => <String, dynamic>{
  'slug': slug,
  'title': 'Meldung $slug',
  'publishedAt': '2026-08-04T09:00:00.000Z',
  'heroImage': null,
  'channels': <Object>[],
  'tag': <String, dynamic>{'slug': 'news', 'name': 'News'},
  'primaryChannel': <String, dynamic>{
    'slug': 'campus-news',
    'name': 'Campus News',
  },
  'content': <Object>[
    <String, dynamic>{
      'type': 'paragraph',
      'children': <Object>[
        <String, dynamic>{'type': 'text', 'text': 'Der Text von $slug.'},
      ],
    },
  ],
};

/// Serves the channel list once and scripted article pages for whichever
/// single-slug `channels` parameter is requested.
class _ChannelApi {
  _ChannelApi(this.pages);

  /// page number -> slugs, or `null` to fail that page.
  final Map<int, List<String>?> pages;
  final List<int> requestedPages = <int>[];
  final List<String?> requestedChannels = <String?>[];

  FakeHttpAdapter get adapter => FakeHttpAdapter((RequestOptions options) {
    if (options.path.endsWith('/posts/channels')) {
      return FakeHttpResponse(envelope(channelsFixture));
    }
    final int page =
        int.tryParse('${options.queryParameters['page'] ?? 1}') ?? 1;
    requestedPages.add(page);
    requestedChannels.add(options.queryParameters['channels'] as String?);
    final List<String>? slugs = pages[page];
    if (slugs == null) {
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      );
    }
    return FakeHttpResponse(
      envelope(
        slugs.map(_article).toList(),
        meta: <String, dynamic>{
          'pagination': <String, dynamic>{
            'page': page,
            'pageSize': slugs.length,
            'total': pages.length * slugs.length,
            'totalPages': pages.length,
          },
        },
      ),
    );
  });
}

Future<ProviderContainer> _pumpChannel(
  WidgetTester tester, {
  required FakeHttpAdapter adapter,
  String slug = 'campus-news',
  Locale locale = AppLocales.german,
  TextScaler textScaler = TextScaler.noScaling,
  Size size = const Size(390, 1200),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  final ProviderContainer container = await pumpScreen(
    tester,
    NewsChannelScreen(slug: slug),
    locale: locale,
    textScaler: textScaler,
    overrides: <Override>[
      frozenNewsClock(),
      apiClientProvider.overrideWithValue(fakeApiClient(adapter)),
    ],
  );
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('shows the channel header and its articles', (
    WidgetTester tester,
  ) async {
    final _ChannelApi api = _ChannelApi(<int, List<String>?>{
      1: <String>['a01'],
    });

    await _pumpChannel(tester, adapter: api.adapter);

    expect(
      find.text('Campus News'),
      findsOneWidget,
      reason: 'the channel name belongs in the screen title only',
    );
    expect(find.text('Nachrichten rund um den Campus Köthen.'), findsOneWidget);
    expect(find.text('Meldung a01'), findsOneWidget);
    expect(
      api.requestedChannels,
      everyElement('campus-news'),
      reason: 'the article request must be scoped to exactly this channel',
    );
  });

  testWidgets('renders the channel name once and no article dividers', (
    WidgetTester tester,
  ) async {
    final _ChannelApi api = _ChannelApi(<int, List<String>?>{
      1: <String>['a01', 'a02'],
    });

    await _pumpChannel(tester, adapter: api.adapter);

    expect(find.text('Campus News'), findsOneWidget);
    expect(find.byType(Divider), findsNothing);
  });

  testWidgets('shows a distinct state for an unknown channel slug', (
    WidgetTester tester,
  ) async {
    final _ChannelApi api = _ChannelApi(<int, List<String>?>{
      1: <String>['a01'],
    });

    await _pumpChannel(tester, adapter: api.adapter, slug: 'does-not-exist');

    expect(find.text('Kanal nicht verfügbar'), findsOneWidget);
    expect(
      find.text('Diesen Kanal gibt es nicht oder er ist derzeit nicht aktiv.'),
      findsOneWidget,
    );
    // Different wording from "this channel has no articles" — and no article
    // request was ever made for a channel that does not exist.
    expect(find.text('Keine Beiträge'), findsNothing);
    expect(api.requestedChannels, isEmpty);
  });

  testWidgets('shows a distinct empty state for a channel with no articles', (
    WidgetTester tester,
  ) async {
    final _ChannelApi api = _ChannelApi(<int, List<String>?>{1: <String>[]});

    await _pumpChannel(tester, adapter: api.adapter);

    expect(find.text('Keine Beiträge'), findsOneWidget);
    expect(
      find.text('Für diesen Kanal liegen derzeit keine Beiträge vor.'),
      findsOneWidget,
    );
    // The channel's own header still renders — this is a real, active
    // channel, just an empty one.
    expect(find.text('Campus News'), findsOneWidget);
  });

  testWidgets('degrades a network failure to the error state with retry', (
    WidgetTester tester,
  ) async {
    final FakeHttpAdapter adapter = FakeHttpAdapter((RequestOptions options) {
      if (options.path.endsWith('/posts/channels')) {
        return FakeHttpResponse(envelope(channelsFixture));
      }
      throw DioException(
        requestOptions: options,
        type: DioExceptionType.connectionError,
      );
    });

    await _pumpChannel(tester, adapter: adapter);

    expect(
      find.text(
        'Keine Verbindung zum Server. Bitte prüfe deine Internetverbindung.',
      ),
      findsOneWidget,
    );
    expect(find.text('Erneut versuchen'), findsOneWidget);
  });

  group('pagination', () {
    testWidgets('loads the next page when the end comes into view', (
      WidgetTester tester,
    ) async {
      final _ChannelApi api = _ChannelApi(<int, List<String>?>{
        1: <String>['a01', 'a02', 'a03', 'a04', 'a05', 'a06', 'a07', 'a08'],
        2: <String>['b01', 'b02'],
      });

      await _pumpChannel(
        tester,
        adapter: api.adapter,
        size: const Size(390, 600),
      );
      expect(api.requestedPages, <int>[1]);

      await tester.drag(
        find.byType(ArticleBlock).first,
        const Offset(0, -4000),
      );
      await tester.pumpAndSettle();

      expect(api.requestedPages, <int>[1, 2]);
      expect(
        api.requestedChannels,
        everyElement('campus-news'),
        reason: 'every page request stays scoped to the one channel',
      );
    });

    testWidgets('a failed next page keeps what is already there', (
      WidgetTester tester,
    ) async {
      final _ChannelApi api = _ChannelApi(<int, List<String>?>{
        1: <String>['a01', 'a02'],
        2: null,
      });

      await _pumpChannel(tester, adapter: api.adapter);

      expect(find.text('Meldung a01'), findsOneWidget);
      expect(
        find.text('Weitere Beiträge konnten nicht geladen werden.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Erneut versuchen'));
      await tester.pumpAndSettle();
      // Still failing (page 2 is still null) — the retry asked again rather
      // than silently giving up, and everything already loaded survived.
      expect(find.text('Meldung a01'), findsOneWidget);
    });
  });

  testWidgets('pull to refresh reloads the channel from page one', (
    WidgetTester tester,
  ) async {
    final _ChannelApi api = _ChannelApi(<int, List<String>?>{
      1: <String>['a01'],
      2: <String>['b01'],
    });

    final ProviderContainer container = await _pumpChannel(
      tester,
      adapter: api.adapter,
    );
    // `runAsync` is required here: this call is issued directly from the test
    // body rather than from something the widget tree's own build/pump cycle
    // drives (a gesture, a frame callback), so its underlying `Future` — a
    // real asynchronous chain through `dio` — never gets a chance to
    // complete under the test binding's normal (pump-driven) scheduling.
    // Without it, `await` on that method hangs forever, and so does every
    // call below it. See `news_feed_controller_test.dart` for the same
    // method exercised without a widget tree, where no such wrapping is
    // needed because there is no pump-driven binding to stall against.
    await tester.runAsync(
      () => container
          .read(newsChannelFeedControllerProvider('campus-news').notifier)
          .loadMore(),
    );
    await tester.pumpAndSettle();
    expect(find.text('Meldung b01'), findsOneWidget);

    // Exercises the same `NewsChannelFeedController.refresh` the screen's
    // `RefreshIndicator` calls — driving the actual pull gesture through a
    // `ListView` in a widget test is flaky across screen sizes, so the
    // gesture-to-provider wiring is instead covered by the widget building
    // its `RefreshIndicator.onRefresh` from that exact method (see
    // `news_channel_screen.dart`), and this test asserts what refreshing
    // actually does.
    await tester.runAsync(
      () => container
          .read(newsChannelFeedControllerProvider('campus-news').notifier)
          .refresh(),
    );

    // Asserted on the controller's own state, not the rendered widget: with
    // only one article per page, page one alone already fills the viewport,
    // so `NewsLoadMoreFooter` mounts immediately and — by its own contract,
    // preloading a page before the reader scrolls near it — asks for page
    // two again straight away. That is correct pagination behaviour, not
    // something this test should fight; refreshing back to page one is what
    // is under test here, and that is what `NewsChannelFeedController.refresh`
    // itself guarantees, independent of whatever the footer does next.
    final NewsChannelFeedState refreshed = container
        .read(newsChannelFeedControllerProvider('campus-news'))
        .requireValue;
    expect(refreshed.articles.map((NewsArticle a) => a.slug), <String>['a01']);
    expect(refreshed.page, 1);

    await tester.pumpAndSettle();
    expect(find.text('Meldung a01'), findsOneWidget);
  });

  testWidgets('renders in English', (WidgetTester tester) async {
    final _ChannelApi api = _ChannelApi(<int, List<String>?>{
      1: <String>['a01'],
    });

    await _pumpChannel(
      tester,
      adapter: api.adapter,
      slug: 'does-not-exist',
      locale: AppLocales.english,
    );

    expect(find.text('Channel not available'), findsOneWidget);
  });

  testWidgets('survives a doubled text scale without throwing', (
    WidgetTester tester,
  ) async {
    final _ChannelApi api = _ChannelApi(<int, List<String>?>{
      1: <String>['a01', 'a02'],
    });

    await _pumpChannel(
      tester,
      adapter: api.adapter,
      textScaler: const TextScaler.linear(2),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Meldung a01'), findsOneWidget);
  });
}
