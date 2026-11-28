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
import '../../../core/network/api_meta.dart';
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
    path: '/calendars/all',
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
    int maxCalendars = 1,
  }) => _fetchEvents(
    locale: locale,
    slugs: slugs,
    from: from,
    to: to,
    maxCalendars: maxCalendars,
  );

  Future<Loaded<List<PublicCalendarEvent>>> fetchEventsDefaultWindow({
    required String locale,
    required List<String> slugs,
    int maxCalendars = 1,
  }) => _fetchEvents(locale: locale, slugs: slugs, maxCalendars: maxCalendars);

  Future<Loaded<List<PublicCalendarEvent>>> _fetchEvents({
    required String locale,
    required List<String> slugs,
    String? from,
    String? to,
    required int maxCalendars,
  }) async {
    if (slugs.isEmpty) {
      return const Loaded(value: <PublicCalendarEvent>[], meta: ApiMeta.empty);
    }
    final limit = maxCalendars.clamp(1, 100);
    final unique = slugs.toSet().toList();
    final results = <Loaded<List<PublicCalendarEvent>>>[];
    String? resolvedFrom = from, resolvedTo = to;
    for (int i = 0; i < unique.length; i += limit) {
      final batch = unique.sublist(i, (i + limit).clamp(0, unique.length));
      final result = await _endpoint.load<List<PublicCalendarEvent>>(
        path: '/calendars/events',
        locale: locale,
        cacheKey: CacheKeys.publicCalendarEvents(
          locale: locale,
          slugs: batch,
          from: resolvedFrom ?? '-',
          to: resolvedTo ?? '-',
        ),
        query: <String, Object?>{
          'calendar': batch,
          'from': ?resolvedFrom,
          'to': ?resolvedTo,
        },
        parse: PublicCalendarEvent.listFromJson,
      );
      results.add(result);
      resolvedFrom ??= result.meta.from;
      resolvedTo ??= result.meta.to;
    }
    return combineCalendarEventLoads(results);
  }

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

/// Preserve partial/offline provenance when a date window or calendar batch is split.
Loaded<List<PublicCalendarEvent>> combineCalendarEventLoads(
  List<Loaded<List<PublicCalendarEvent>>> parts,
) {
  if (parts.isEmpty) {
    return const Loaded(value: <PublicCalendarEvent>[], meta: ApiMeta.empty);
  }
  final byId = <String, PublicCalendarEvent>{
    for (final part in parts)
      for (final event in part.value) event.id: event,
  };
  final dates = parts.map((p) => p.cachedAt).whereType<DateTime>().toList()
    ..sort();
  return Loaded(
    value: byId.values.toList(),
    fromCache: parts.any((p) => p.fromCache),
    cachedAt: dates.firstOrNull,
    meta: ApiMeta.fromJson({
      ...parts.first.meta.toJson(),
      'truncated': parts.any((p) => p.meta.truncated),
      'dataStale': parts.any((p) => p.meta.dataStale),
      'translationFallback': parts.any((p) => p.meta.translationFallback),
    }),
  );
}
