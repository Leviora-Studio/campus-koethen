// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'api_meta.dart';

/// A successfully resolved value together with its provenance.
///
/// [fromCache] drives the visible offline/stale labelling: the UI must always
/// be able to tell the user that they are looking at stored content.
class Loaded<T> {
  const Loaded({
    required this.value,
    required this.meta,
    this.fromCache = false,
    this.cachedAt,
  });

  final T value;
  final ApiMeta meta;
  final bool fromCache;
  final DateTime? cachedAt;

  Loaded<R> map<R>(R Function(T value) transform) => Loaded<R>(
    value: transform(value),
    meta: meta,
    fromCache: fromCache,
    cachedAt: cachedAt,
  );
}
