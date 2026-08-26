// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:campus_koethen/core/network/api_meta.dart';
import 'package:campus_koethen/core/network/loaded.dart';
import 'package:campus_koethen/features/campusmap/application/campus_map_providers.dart';
import 'package:campus_koethen/features/campusmap/domain/room.dart';
import 'package:campus_koethen/features/campusmap/presentation/room_catalog_refresh_host.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('loads on app start and checks again when the app resumes', (
    WidgetTester tester,
  ) async {
    int loads = 0;
    final ProviderContainer container = ProviderContainer(
      overrides: [
        roomsProvider.overrideWith((Ref ref) async {
          loads += 1;
          return const Loaded<List<Room>>(value: <Room>[], meta: ApiMeta.empty);
        }),
      ],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const RoomCatalogRefreshHost(child: SizedBox()),
      ),
    );
    await tester.pump();
    expect(loads, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
    expect(loads, 1);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(loads, 2);
  });
}
