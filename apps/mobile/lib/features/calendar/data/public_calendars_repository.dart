// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cache/cache_keys.dart';
import '../../../core/cache/cache_providers.dart';
import '../../../core/cache/content_cache.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/cached_endpoint.dart';
import '../../../core/network/json.dart';
import '../../../core/network/loaded.dart';
import '../../../core/network/network_providers.dart';
import '../domain/public_calendar.dart';

/// Talks to the public-calendar endpoints of the Campus API.
///
/// The app only ever sees the Campus API; the ICS feed, the Google calendar id
/// and Google itself are never contacted from the device for these calendars.
class PublicCalendarsRepository {
  PublicCalendarsRepository({
    required ApiClient client,
    required ContentCache cache,
  }) : _client = client,
       _endpoint = CachedEndpoint(client: client, cache: cache);

  final ApiClient _client;
  final CachedEndpoint _endpoint;

  Future<Loaded<List<PublicCalendar>>> fetchCalendars({
    required String locale,
  }) => _endpoint.load(
    path: '/calendars',
    cacheKey: CacheKeys.publicCalendars(locale),
    locale: locale,
    parse: PublicCalendar.listFromJson,
  );

  /// Aggregated events of the SELECTED calendars. Callers must not call this
  /// with an empty selection — an empty selection means "no events", never all.
  Future<Loaded<List<PublicCalendarEvent>>> fetchEvents({
    required String locale,
    required List<String> slugs,
    required String from,
    required String to,
  }) => _endpoint.load(
    path: '/calendars/events',
    cacheKey: CacheKeys.publicCalendarEvents(
      locale: locale,
      slugs: slugs,
      from: from,
      to: to,
    ),
    locale: locale,
    query: <String, Object?>{'calendar': slugs, 'from': from, 'to': to},
    parse: PublicCalendarEvent.listFromJson,
  );

  /// Aggregated events of the selected calendars for the server's own
  /// default window: `from`/`to` are deliberately omitted from the request,
  /// so the server-environment window applies. Callers must not call this
  /// with an empty selection — an empty selection means "no events", never
  /// all. The actually-resolved window is [Loaded.meta]`.from`/`.to`, which
  /// governs both the cache key and any reconciliation against it; it may
  /// differ from any previous call without requiring an app release.
  Future<Loaded<List<PublicCalendarEvent>>> fetchEventsDefaultWindow({
    required String locale,
    required List<String> slugs,
  }) => _endpoint.load(
    path: '/calendars/events',
    // Keyed by "unresolved" until the first response is known; the caller
    // that needs a window-stable key re-keys by the returned meta.from/to.
    cacheKey: CacheKeys.publicCalendarEvents(
      locale: locale,
      slugs: slugs,
      from: '-',
      to: '-',
    ),
    locale: locale,
    query: <String, Object?>{'calendar': slugs},
    parse: PublicCalendarEvent.listFromJson,
  );

  /// A backend-constructed combined Google Calendar embed URL. Not cached — it
  /// is cheap, selection-specific and only used on an explicit user action.
  Future<String> fetchGoogleViewUrl({
    required List<String> slugs,
    required String locale,
  }) async {
    final response = await _client.get<String>(
      '/calendars/google-view-url',
      locale: locale,
      query: <String, Object?>{'calendar': slugs},
      parse: (Object? data) => asString(asJsonMap(data)?['url']) ?? '',
    );
    return response.data;
  }
}

final Provider<PublicCalendarsRepository> publicCalendarsRepositoryProvider =
    Provider<PublicCalendarsRepository>(
      (Ref ref) => PublicCalendarsRepository(
        client: ref.watch(apiClientProvider),
        cache: ref.watch(contentCacheProvider),
      ),
    );
