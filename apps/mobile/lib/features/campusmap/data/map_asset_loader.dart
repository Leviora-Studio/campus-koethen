// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'dart:convert';

import 'package:flutter/services.dart' show AssetBundle, rootBundle;

import '../domain/map_catalog.dart';

/// Loads the generated map catalogue from the app bundle.
///
/// The asset is produced and validated by `packages/campus-map`, so this only
/// reads and parses it. Nothing is ever fetched over the network: the map is
/// part of the app, which is what keeps it working offline and free of any
/// third-party request.
class MapAssetLoader {
  const MapAssetLoader({this.assetPath = defaultAssetPath, this.bundle});

  static const String defaultAssetPath = 'assets/maps/map_catalog.json';

  final String assetPath;

  /// Injectable for tests; defaults to the app bundle.
  final AssetBundle? bundle;

  Future<MapCatalog> load() async {
    final String raw = await (bundle ?? rootBundle).loadString(assetPath);
    final MapCatalog? catalog = MapCatalog.fromJson(jsonDecode(raw) as Object?);
    if (catalog == null) {
      throw StateError('The bundled map catalogue at $assetPath is unusable');
    }
    return catalog;
  }
}
