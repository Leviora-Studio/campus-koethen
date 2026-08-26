// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

/// Tapping a room on the plan must select that room — before and after the
/// reader has zoomed and dragged.
///
/// The hit test itself is a pure function with its own tests; what these tests
/// guard is the part that cannot be checked in isolation: that a screen
/// coordinate arrives in the geometry's coordinate system at all, whatever the
/// current pan and zoom are.
library;

import 'package:campus_koethen/core/locale/locale_mode.dart';
import 'package:campus_koethen/features/campusmap/domain/map_catalog.dart';
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
  viewBox: Rect.fromLTWH(0, 0, 1000, 1000),
  sortOrder: 10,
);

MapRoomGeometry _room(String key, Rect bounds) => MapRoomGeometry(
  roomKey: key,
  buildingKey: 'test-building',
  floorKey: 'test-building-level2',
  svgElementId: key,
  focus: bounds.center,
  bounds: bounds,
);

/// Top-left quarter and bottom-right quarter, with plenty of floor between.
final MapRoomGeometry _a = _room('a', const Rect.fromLTWH(0, 0, 300, 300));
final MapRoomGeometry _b = _room('b', const Rect.fromLTWH(700, 700, 300, 300));

const Size _viewport = Size(500, 500);

Future<List<String>> _pump(
  WidgetTester tester, {
  MapRoomGeometry? selected,
}) async {
  tester.view.physicalSize = const Size(700, 700);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });

  final List<String> tapped = <String>[];
  await tester.pumpWidget(
    MaterialApp(
      locale: AppLocales.german,
      supportedLocales: AppLocales.supported,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: Scaffold(
        body: Center(
          child: SizedBox(
            width: _viewport.width,
            height: _viewport.height,
            child: FloorMapView(
              floor: _floor,
              rooms: <MapRoomGeometry>[_a, _b],
              selected: selected,
              onRoomTap: tapped.add,
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return tapped;
}

/// The centre of the plan area, in screen coordinates.
Offset _planCentre(WidgetTester tester) =>
    tester.getCenter(find.byType(FloorMapView));

void main() {
  testWidgets('a tap on a room reports that room', (WidgetTester tester) async {
    final List<String> tapped = await _pump(tester);
    final Offset centre = _planCentre(tester);

    // The plan is 1000x1000 in a 500x500 box: one plan unit is half a pixel,
    // and the centre of the view is plan (500, 500). Room "a" fills the
    // top-left quarter.
    await tester.tapAt(centre - const Offset(150, 150));
    await tester.pumpAndSettle();

    expect(tapped, <String>['a']);
  });

  testWidgets('a tap on empty floor does nothing at all', (
    WidgetTester tester,
  ) async {
    final List<String> tapped = await _pump(tester);

    // Dead centre: between the two rooms and far from both.
    await tester.tapAt(_planCentre(tester));
    await tester.pumpAndSettle();

    expect(tapped, isEmpty);
  });

  testWidgets('the other room is the other room', (WidgetTester tester) async {
    final List<String> tapped = await _pump(tester);

    await tester.tapAt(_planCentre(tester) + const Offset(150, 150));
    await tester.pumpAndSettle();

    expect(tapped, <String>['b']);
  });

  testWidgets('it still works after zooming and dragging', (
    WidgetTester tester,
  ) async {
    // The real risk: a hand-rolled coordinate transform that is only correct at
    // scale 1. The map no longer zooms on its own, so the state has to be set
    // up the way a user reaches it — by pinching.
    final List<String> tapped = await _pump(tester, selected: _a);
    final FloorMapViewState state = tester.state<FloorMapViewState>(
      find.byType(FloorMapView),
    );
    await _pinch(tester);
    expect(
      state.currentTransform,
      isNot(Matrix4.identity()),
      reason: 'the pinch must actually have moved the plan',
    );

    // …and dragged back into the top-left corner, which is where room "a" is.
    await tester.drag(find.byType(FloorMapView), const Offset(600, 600));
    await tester.pumpAndSettle();
    expect(state.currentTransform.getTranslation().x, closeTo(0, 0.01));

    // The plan is 1000x1000 in a 500x500 box at scale 2, held at the corner:
    // one plan unit is one pixel again, so room "a"'s centre is at (150, 150).
    await tester.tapAt(
      tester.getTopLeft(find.byType(FloorMapView)) + const Offset(150, 150),
    );
    await tester.pumpAndSettle();

    expect(tapped, <String>['a']);
  });

  testWidgets('the plan can still be dragged', (WidgetTester tester) async {
    // A tap detector that swallowed drags would trade one gesture for another.
    // Zoomed in first: at overview the plan fills the viewport exactly and the
    // InteractiveViewer has nowhere to pan it, so a drag legitimately does
    // nothing and would prove nothing either.
    final List<String> tapped = await _pump(tester, selected: _a);
    final FloorMapViewState state = tester.state<FloorMapViewState>(
      find.byType(FloorMapView),
    );
    await _pinch(tester);
    final Matrix4 before = state.currentTransform.clone();

    await tester.drag(find.byType(FloorMapView), const Offset(-80, -40));
    await tester.pumpAndSettle();

    expect(state.currentTransform, isNot(before));
    expect(tapped, isEmpty, reason: 'a drag is not a tap');
  });

  testWidgets('a room outside the given list never answers', (
    WidgetTester tester,
  ) async {
    // The screen passes only the visible floor; this is the guard that the
    // widget does not go looking for more.
    final List<String> tapped = <String>[];
    tester.view.physicalSize = const Size(700, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        locale: AppLocales.german,
        supportedLocales: AppLocales.supported,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: _viewport.width,
              height: _viewport.height,
              child: FloorMapView(
                floor: _floor,
                rooms: const <MapRoomGeometry>[],
                selected: null,
                onRoomTap: tapped.add,
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tapAt(_planCentre(tester) - const Offset(150, 150));
    await tester.pumpAndSettle();

    expect(tapped, isEmpty);
  });
}

/// Zooms the plan in with a two-finger pinch, the way a user does.
Future<void> _pinch(WidgetTester tester) async {
  final FloorMapViewState state = tester.state<FloorMapViewState>(
    find.byType(FloorMapView),
  );
  final Offset centre = tester.getCenter(find.byType(FloorMapView));
  const double span = 100;
  for (int i = 0; i < 12; i++) {
    if (state.currentTransform.getMaxScaleOnAxis() >= 2) return;
    final TestGesture left = await tester.startGesture(
      centre - const Offset(span, 0),
    );
    final TestGesture right = await tester.startGesture(
      centre + const Offset(span, 0),
    );
    await tester.pump();
    await left.moveTo(centre - const Offset(span * 2, 0));
    await right.moveTo(centre + const Offset(span * 2, 0));
    await tester.pump();
    await left.up();
    await right.up();
    await tester.pumpAndSettle();
  }
  fail('could not pinch the plan in');
}
