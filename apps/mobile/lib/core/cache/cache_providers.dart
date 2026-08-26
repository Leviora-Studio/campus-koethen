// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'content_cache.dart';

/// The persistent content cache.
///
/// Overridden in `main()` with the hive_ce backed implementation. The default
/// is an in-memory cache so widget tests never touch the file system.
final Provider<ContentCache> contentCacheProvider = Provider<ContentCache>(
  (Ref ref) => SafeContentCache(MemoryContentCache()),
);
