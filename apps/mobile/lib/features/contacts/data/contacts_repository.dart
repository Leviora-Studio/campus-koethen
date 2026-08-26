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
import 'contact_models.dart';
import 'contact_search_models.dart';

/// Reads contact areas from the Campus API with a transparent offline cache.
class ContactsRepository {
  ContactsRepository({required ApiClient client, required ContentCache cache})
    : _endpoint = CachedEndpoint(client: client, cache: cache);

  final CachedEndpoint _endpoint;

  Future<Loaded<List<ContactArea>>> fetchAreas({required String locale}) {
    return _endpoint.load<List<ContactArea>>(
      path: '/contact-areas',
      cacheKey: CacheKeys.contactAreas(locale),
      locale: locale,
      parse: ContactArea.listFromJson,
    );
  }

  /// The search index: every area with its persons and rooms, in one request.
  ///
  /// Cached like every other content response, so the search keeps working
  /// offline — and so opening the search does not wait for the network when the
  /// index has been loaded before.
  Future<Loaded<List<ContactSearchArea>>> fetchSearchIndex({
    required String locale,
  }) {
    return _endpoint.load<List<ContactSearchArea>>(
      path: '/contact-areas/search-index',
      cacheKey: CacheKeys.contactSearchIndex(locale),
      locale: locale,
      parse: ContactSearchArea.listFromJson,
    );
  }

  Future<Loaded<ContactArea>> fetchArea({
    required String locale,
    required String slug,
  }) {
    return _endpoint.load<ContactArea>(
      path: '/contact-areas/$slug',
      cacheKey: CacheKeys.contactArea(locale, slug),
      locale: locale,
      parse: (Object? data) {
        final ContactArea? area = ContactArea.fromJson(data);
        if (area == null) {
          throw const FormatException('Malformed contact area payload');
        }
        return area;
      },
    );
  }
}

final Provider<ContactsRepository> contactsRepositoryProvider =
    Provider<ContactsRepository>(
      (Ref ref) => ContactsRepository(
        client: ref.watch(apiClientProvider),
        cache: ref.watch(contentCacheProvider),
      ),
    );
