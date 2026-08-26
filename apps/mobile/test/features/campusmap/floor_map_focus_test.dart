// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

/// Selecting a room must bring THAT room into view.
///
/// The plan is laid out inside a `Center`, so it is offset within the viewport
/// whenever it does not fill it completely. Focusing in plain plan coordinates
/// therefore lands next to the intended room — which is exactly what the first
/// real run in a browser showed: picking B.222 scrolled to B.216.
library;

import 'package:campus_koethen/features/campusmap/domain/map_catalog.dart';
import 'package:campus_koethen/core/locale/locale_mode.dart';
import 'package:campus_koethen/features/campusmap/presentation/floor_map_view.dart';
import 'package:campus_koethen/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

const MapFloor _floor = MapFloor(
  floorKey: 'test-building-level2',
  buildingKey: 'test-building',
  level: 2,
  name: LocalisedName(de: '2. Obergeschoss', en: 'Second floor'),
  svgAsset: 'assets/maps/test-building/level2.svg',
  viewBox: Rect.fromLTWH(0, 0, 1900, 1080),
  sortOrder: 10,
);

MapRoomGeometry _room({required Offset focus, required Rect bounds}) =>
    MapRoomGeometry(
      roomKey: 'test-building-level2-b222',
      buildingKey: 'test-building',
      floorKey: 'test-building-level2',
      svgElementId: 'room-test-building-level2-b222',
      focus: focus,
      bounds: bounds,
    );

/// Zooms in until the plan is at least [target] times its overview size.
///
/// The map no longer zooms by itself, so anything about the transform under a
/// zoom has to put the map into that state the way a user does — and a single
/// pinch only gets part of the way, because the gesture pays the touch slop
/// before the viewer starts scaling.
Future<void> zoomTo(
  WidgetTester tester,
  GlobalKey<FloorMapViewState> key,
  double target,
) async {
  for (int i = 0; i < 12; i++) {
    if (key.currentState!.currentTransform.getMaxScaleOnAxis() >= target) {
      return;
    }
    await pinch(tester, 2);
  }
  fail('could not pinch the plan to $target');
}

/// One two-finger pinch that spreads the fingers by [factor].
Future<void> pinch(WidgetTester tester, double factor) async {
  final Offset centre = tester.getCenter(find.byType(FloorMapView));
  const double span = 100;
  final TestGesture left = await tester.startGesture(
    centre - const Offset(span, 0),
  );
  final TestGesture right = await tester.startGesture(
    centre + const Offset(span, 0),
  );
  await tester.pump();
  await left.moveTo(centre - Offset(span * factor, 0));
  await right.moveTo(centre + Offset(span * factor, 0));
  await tester.pump();
  await left.up();
  await right.up();
  await tester.pumpAndSettle();
}

Future<GlobalKey<FloorMapViewState>> pumpMap(
  WidgetTester tester, {
  MapRoomGeometry? selected,
  Size viewport = const Size(1200, 400),
  List<MapRoomGeometry> rooms = const <MapRoomGeometry>[],
  ValueChanged<String>? onRoomTap,
  GlobalKey<FloorMapViewState>? key,
}) async {
  // The default 800x600 test surface would silently shrink the requested
  // viewport and make the expectations below measure something else.
  tester.view.physicalSize = Size(viewport.width + 200, viewport.height + 200);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  key ??= GlobalKey<FloorMapViewState>();
  await tester.pumpWidget(
    MaterialApp(
      locale: AppLocales.german,
      supportedLocales: AppLocales.supported,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: viewport.width,
            height: viewport.height,
            child: FloorMapView(
              key: key,
              floor: _floor,
              rooms: rooms,
              selected: selected,
              onRoomTap: onRoomTap,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return key;
}

/// Where a point of the PLAN ends up inside the viewport.
Offset planPointInViewport(
  FloorMapViewState state,
  Offset planPoint,
  Size viewport,
) {
  final double planScale = state.planScale;
  final Size planSize = Size(
    _floor.viewBox.width * planScale,
    _floor.viewBox.height * planScale,
  );
  // The plan sits centred inside the viewport before the transform applies.
  final Offset origin = Offset(
    (viewport.width - planSize.width) / 2,
    (viewport.height - planSize.height) / 2,
  );
  final Offset inChild = origin + planPoint * planScale;
  return MatrixUtils.transformPoint(state.currentTransform, inChild);
}

void main() {
  testWidgets('without a selection the plan is shown untransformed', (
    WidgetTester tester,
  ) async {
    final GlobalKey<FloorMapViewState> key = await pumpMap(tester);
    expect(key.currentState!.currentTransform, Matrix4.identity());
  });

  testWidgets('a room already in view is left exactly where it is', (
    WidgetTester tester,
  ) async {
    // At overview the whole floor is on screen by construction, so there is
    // nothing to bring into view — and moving the plan anyway would push the
    // other end of it off the screen.
    final GlobalKey<FloorMapViewState> key = await pumpMap(
      tester,
      selected: _room(
        focus: const Offset(775, 570),
        bounds: const Rect.fromLTWH(725, 480, 100, 180),
      ),
    );

    expect(key.currentState!.currentTransform, Matrix4.identity());
  });

  testWidgets('a room out of view is centred, offset and all', (
    WidgetTester tester,
  ) async {
    // The plan sits inside a Center, so focusing in plain plan coordinates
    // lands next to the intended room — the case the browser run got wrong,
    // where picking B.222 scrolled to B.216. Zoomed in is the only state where
    // the map still moves for a selection, so that is where this is checked.
    const Size viewport = Size(1200, 400);
    final GlobalKey<FloorMapViewState> key = GlobalKey<FloorMapViewState>();
    await pumpMap(tester, viewport: viewport, key: key);
    await zoomTo(tester, key, 3);
    // Shoved into the far corner, so the room below is genuinely off screen.
    await tester.drag(find.byType(FloorMapView), const Offset(-3000, -3000));
    await tester.pumpAndSettle();

    // A room low and left of centre — B.222 versus B.216, in the original.
    final MapRoomGeometry room = _room(
      focus: const Offset(775, 570),
      bounds: const Rect.fromLTWH(725, 480, 100, 180),
    );
    await pumpMap(tester, viewport: viewport, key: key, selected: room);

    final Offset landed = planPointInViewport(
      key.currentState!,
      room.focus,
      viewport,
    );
    expect(
      landed.dx,
      closeTo(viewport.width / 2, 1.0),
      reason: 'the focused room must be centred horizontally',
    );
    expect(
      landed.dy,
      closeTo(viewport.height / 2, 1.0),
      reason: 'the focused room must be centred vertically',
    );
  });

  testWidgets('a room at the far right is centred just as precisely', (
    WidgetTester tester,
  ) async {
    const Size viewport = Size(1200, 400);
    final GlobalKey<FloorMapViewState> key = GlobalKey<FloorMapViewState>();
    await pumpMap(tester, viewport: viewport, key: key);
    await zoomTo(tester, key, 3);
    // Held at the near corner, so a room at the other end is off screen.
    await tester.drag(find.byType(FloorMapView), const Offset(3000, 3000));
    await tester.pumpAndSettle();

    final MapRoomGeometry room = _room(
      focus: const Offset(1750, 300),
      bounds: const Rect.fromLTWH(1700, 200, 100, 200),
    );
    await pumpMap(tester, viewport: viewport, key: key, selected: room);

    final Offset landed = planPointInViewport(
      key.currentState!,
      room.focus,
      viewport,
    );
    expect(landed.dx, closeTo(viewport.width / 2, 1.0));
    expect(landed.dy, closeTo(viewport.height / 2, 1.0));
  });

  testWidgets('centring never pans past what the viewer allows', (
    WidgetTester tester,
  ) async {
    // A transform outside the viewer's own limits is not a view the user can
    // keep: the next gesture throws the excess away with a visible jump.
    const Size viewport = Size(1200, 400);
    final GlobalKey<FloorMapViewState> key = GlobalKey<FloorMapViewState>();
    await pumpMap(tester, viewport: viewport, key: key);
    await zoomTo(tester, key, 3);
    await tester.drag(find.byType(FloorMapView), const Offset(-3000, -3000));
    await tester.pumpAndSettle();
    await pumpMap(
      tester,
      viewport: viewport,
      key: key,
      selected: _room(
        focus: const Offset(50, 40),
        bounds: const Rect.fromLTWH(20, 20, 60, 40),
      ),
    );
    final Matrix4 focused = key.currentState!.currentTransform.clone();

    await tester.drag(find.byType(FloorMapView), const Offset(-1, 0));
    await tester.pumpAndSettle();

    // The origin's image under the matrix is its translation.
    final Offset after = MatrixUtils.transformPoint(
      key.currentState!.currentTransform,
      Offset.zero,
    );
    final Offset before = MatrixUtils.transformPoint(focused, Offset.zero);
    expect((after - before).distance, lessThan(2.0));
  });

  testWidgets(
    'selecting a room does not auto-zoom the plan (scale remains 1.0)',
    (WidgetTester tester) async {
      // Under LEVIORA-47, selecting a room preserves the full floor overview
      // (scale = 1.0) and centers the room without jumping in zoom level.
      final GlobalKey<FloorMapViewState> key = await pumpMap(
        tester,
        selected: _room(
          focus: const Offset(775, 570),
          bounds: const Rect.fromLTWH(770, 565, 10, 10),
        ),
        viewport: const Size(1200, 400),
      );

      final double scale = key.currentState!.currentTransform
          .getMaxScaleOnAxis();
      expect(
        scale,
        closeTo(1.0, 0.001),
        reason:
            'selecting a room must not automatically zoom in beyond overview',
      );
    },
  );

  testWidgets('the automatic cap does not limit pinching', (
    WidgetTester tester,
  ) async {
    final GlobalKey<FloorMapViewState> key = await pumpMap(
      tester,
      selected: _room(
        focus: const Offset(775, 570),
        bounds: const Rect.fromLTWH(770, 565, 10, 10),
      ),
    );

    final InteractiveViewer viewer = tester.widget<InteractiveViewer>(
      find.byType(InteractiveViewer),
    );
    expect(
      viewer.maxScale,
      greaterThan(kMaxFocusScale),
      reason: 'a closer look stays available on request',
    );
    expect(key.currentState, isNotNull);
  });

  testWidgets('resetting returns to the untransformed overview', (
    WidgetTester tester,
  ) async {
    final GlobalKey<FloorMapViewState> key = await pumpMap(
      tester,
      selected: _room(
        focus: const Offset(775, 570),
        bounds: const Rect.fromLTWH(725, 480, 100, 180),
      ),
    );
    await zoomTo(tester, key, 2);
    expect(key.currentState!.currentTransform, isNot(Matrix4.identity()));

    key.currentState!.resetView();
    await tester.pumpAndSettle();
    expect(key.currentState!.currentTransform, Matrix4.identity());
  });
}
