// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/loaded.dart';
import '../../news/data/news_models.dart';
import '../../news/data/news_repository.dart';

/// Page size requested per call to `/v1/posts/events`. The server caps it at
/// 50; this repository always asks for the maximum to keep the page count —
/// and therefore the request count — as low as possible.
const int kEventPostsPageSize = 50;

/// Hard ceiling on how many pages this repository will fetch for one load,
/// per contract ("maximal 10 Seiten à 50").
const int kEventPostsMaxPages = 10;

/// All event posts loaded for one window, plus whether the 10×50 ceiling was
/// reached before the server's own last page.
class EventPostsResult {
  const EventPostsResult({
    required this.articles,
    required this.isTruncated,
    required this.from,
    required this.to,
    this.fromCache = false,
    this.cachedAt,
  });

  final List<NewsArticle> articles;

  /// `true` when more pages existed than this load actually delivered —
  /// because the 10×50 ceiling was reached, or because a later page could not
  /// be fetched at all. Either way the UI says so instead of presenting a
  /// silently incomplete list as complete.
  final bool isTruncated;

  /// The server-resolved window this result covers (`meta.from`/`meta.to` of
  /// the first page) — governs the cache key and any saved-list
  /// reconciliation. `null` only when every page came from the cache and the
  /// cached envelope predates this field (defensive, should not occur once
  /// the cache has been refreshed once).
  final String? from;
  final String? to;

  /// `true` when ANY page of this result came from the cache — not just the
  /// first. The saved-list orphan rule may only run on a window that was
  /// genuinely loaded live from end to end, so a single cached page has to be
  /// visible here.
  final bool fromCache;
  final DateTime? cachedAt;
}

/// Loads every event post page for a window, up to [kEventPostsMaxPages].
///
/// The client sends no default `from`/`to`: passing both `null` (the common
/// path) lets the server resolve its own environment-configured window, which
/// is then read back from the first page's meta and used for every
/// subsequent page request, so the whole load is internally consistent even
/// if the server's default changed between the first and a later page.
class EventPostsRepository {
  const EventPostsRepository(this._newsRepository);

  final NewsRepository _newsRepository;

  Future<EventPostsResult> fetchAllEventPosts({
    required String locale,
    String? channelsParameter,
    String? from,
    String? to,
  }) async {
    final Loaded<NewsPage> first = await _newsRepository.fetchEventPosts(
      locale: locale,
      channelsParameter: channelsParameter,
      from: from,
      to: to,
      page: 1,
      pageSize: kEventPostsPageSize,
    );

    final List<NewsArticle> articles = List<NewsArticle>.of(
      first.value.articles,
    );
    // Once the window is resolved, every further page request repeats it
    // explicitly — a page must never silently drift to a newer default.
    final String? resolvedFrom = first.value.from;
    final String? resolvedTo = first.value.to;

    int fetchedPages = 1;
    int totalPages = first.value.totalPages;
    bool isTruncated = false;
    bool fromCache = first.fromCache;

    /// One page, or `null` when it could not be had.
    ///
    /// Only page 1 has a cache fallback, so offline a later page simply
    /// cannot be fetched. Throwing would discard the pages already in hand and
    /// leave the reader with nothing — a partial list, honestly marked as
    /// truncated, is strictly better than an empty screen.
    Future<Loaded<NewsPage>?> fetchPage(int page) async {
      try {
        return await _newsRepository.fetchEventPosts(
          locale: locale,
          channelsParameter: channelsParameter,
          from: resolvedFrom ?? from,
          to: resolvedTo ?? to,
          page: page,
          pageSize: kEventPostsPageSize,
        );
      } catch (_) {
        return null;
      }
    }

    // The first page already says how many there are, and the rest do not
    // depend on one another — so they are asked for together rather than one
    // after the other. Ten pages used to mean ten full round trips before the
    // event overview could show anything.
    //
    // They are then folded in **page order**, which is what keeps the article
    // order, `isTruncated`, `fromCache` and the behaviour on a failing page
    // exactly as they were when the loop was sequential.
    final int plannedLast = totalPages < kEventPostsMaxPages
        ? totalPages
        : kEventPostsMaxPages;
    final List<Loaded<NewsPage>?> pages = await Future.wait<Loaded<NewsPage>?>(
      <Future<Loaded<NewsPage>?>>[
        for (int page = 2; page <= plannedLast; page++) fetchPage(page),
      ],
    );

    bool stopped = false;
    for (final Loaded<NewsPage>? page in pages) {
      // A later page may report a smaller total than the first one did; the
      // sequential loop stopped there, so this does too.
      if (fetchedPages >= totalPages) break;
      if (fetchedPages >= kEventPostsMaxPages || page == null) {
        isTruncated = true;
        stopped = true;
        break;
      }
      articles.addAll(page.value.articles);
      fromCache = fromCache || page.fromCache;
      totalPages = page.value.totalPages;
      fetchedPages += 1;
    }

    // A later page may also report a LARGER total than the first one did — new
    // posts published mid-load. Those extra pages were not planned for, so
    // they are fetched the old way, one at a time. Rare enough that a second
    // round trip is the right trade for not over-fetching on every load.
    while (!stopped && fetchedPages < totalPages) {
      if (fetchedPages >= kEventPostsMaxPages) {
        isTruncated = true;
        break;
      }
      final Loaded<NewsPage>? page = await fetchPage(fetchedPages + 1);
      if (page == null) {
        isTruncated = true;
        break;
      }
      articles.addAll(page.value.articles);
      fromCache = fromCache || page.fromCache;
      totalPages = page.value.totalPages;
      fetchedPages += 1;
    }

    return EventPostsResult(
      articles: List<NewsArticle>.unmodifiable(articles),
      isTruncated: isTruncated,
      from: resolvedFrom,
      to: resolvedTo,
      fromCache: fromCache,
      cachedAt: first.cachedAt,
    );
  }
}

final Provider<EventPostsRepository> eventPostsRepositoryProvider =
    Provider<EventPostsRepository>(
      (Ref ref) => EventPostsRepository(ref.watch(newsRepositoryProvider)),
    );
