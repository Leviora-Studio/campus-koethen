// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../cache/cache_keys.dart';
import '../cache/cache_providers.dart';
import '../cache/content_cache.dart';
import '../locale/locale_providers.dart';
import '../network/api_client.dart';
import '../network/cached_endpoint.dart';
import '../network/loaded.dart';
import '../network/network_providers.dart';
import 'app_environment.dart';

class AppEnvironmentRepository {
  AppEnvironmentRepository({
    required ApiClient client,
    required ContentCache cache,
  }) : _endpoint = CachedEndpoint(client: client, cache: cache);

  final CachedEndpoint _endpoint;

  Future<Loaded<AppEnvironment>> fetch({required String locale}) =>
      _endpoint.load<AppEnvironment>(
        path: '/environment',
        cacheKey: CacheKeys.appEnvironment,
        locale: locale,
        parse: AppEnvironment.fromJson,
      );
}

final Provider<AppEnvironmentRepository> appEnvironmentRepositoryProvider =
    Provider<AppEnvironmentRepository>(
      (Ref ref) => AppEnvironmentRepository(
        client: ref.watch(apiClientProvider),
        cache: ref.watch(contentCacheProvider),
      ),
    );

final FutureProvider<Loaded<AppEnvironment>> appEnvironmentProvider =
    FutureProvider<Loaded<AppEnvironment>>((Ref ref) {
      return ref
          .watch(appEnvironmentRepositoryProvider)
          .fetch(locale: ref.watch(localeCodeProvider));
    }, retry: (_, _) => null);
