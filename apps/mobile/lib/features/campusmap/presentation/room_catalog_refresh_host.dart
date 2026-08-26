// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/campus_map_providers.dart';

/// Keeps the locally searched room catalogue reasonably current.
///
/// Watching [roomsProvider] loads it on a cold app start. Returning to the
/// foreground invalidates the provider so the repository can check the
/// persistent cache age. A response younger than twelve hours is reused
/// without a request; an older one is refreshed from `/v1/rooms` and remains
/// available as an offline fallback if that request fails.
class RoomCatalogRefreshHost extends ConsumerStatefulWidget {
  const RoomCatalogRefreshHost({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<RoomCatalogRefreshHost> createState() =>
      _RoomCatalogRefreshHostState();
}

class _RoomCatalogRefreshHostState extends ConsumerState<RoomCatalogRefreshHost>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.invalidate(roomsProvider);
    }
  }

  @override
  Widget build(BuildContext context) {
    // This root-level watch deliberately starts the load even when the user
    // has not opened the map during this app session.
    ref.watch(roomsProvider);
    return widget.child;
  }
}
