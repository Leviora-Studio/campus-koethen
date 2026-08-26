// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/cache/cache_keys.dart';
import '../../../core/cache/cache_providers.dart';
import '../../../core/cache/content_cache.dart';
import '../../../core/network/api_client.dart';
import '../../../core/network/cached_endpoint.dart';
import '../../../core/network/loaded.dart';
import '../../../core/network/network_providers.dart';
import '../domain/room.dart';

/// Room metadata changes rarely. Reuse the last successful response for this
/// long before checking the API again on app start or resume.
const Duration kRoomCatalogRefreshInterval = Duration(hours: 12);

/// Reads the room catalogue from the Campus API with a transparent offline
/// cache — the same mechanism every other content feature uses.
///
/// The app talks to `/v1` only. It never contacts Strapi, and it never writes
/// anything back to the CMS.
class RoomsRepository {
  RoomsRepository({required ApiClient client, required ContentCache cache})
    : _endpoint = CachedEndpoint(client: client, cache: cache);

  final CachedEndpoint _endpoint;

  Future<Loaded<List<Room>>> fetchRooms({required String locale}) {
    return _endpoint.load<List<Room>>(
      path: '/rooms',
      cacheKey: CacheKeys.rooms(locale),
      locale: locale,
      parse: Room.listFromJson,
      freshFor: kRoomCatalogRefreshInterval,
    );
  }
}

final Provider<RoomsRepository> roomsRepositoryProvider =
    Provider<RoomsRepository>(
      (Ref ref) => RoomsRepository(
        client: ref.watch(apiClientProvider),
        cache: ref.watch(contentCacheProvider),
      ),
    );
