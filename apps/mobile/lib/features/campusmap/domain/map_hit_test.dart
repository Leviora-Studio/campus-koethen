// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'dart:math' as math;

import 'package:flutter/painting.dart';

import 'map_catalog.dart';

/// Which room a tap landed on.
///
/// A pure function on plan coordinates, deliberately kept out of the widget:
/// the geometry decides, and the rules below are far easier to get right — and
/// to keep right — as something a test can state directly.
///
/// [point] is in **plan units**, the same space [MapRoomGeometry.bounds] uses.
/// The caller converts from pixels and passes only the rooms of the floor that
/// is actually on screen; a room one storey up must never answer a tap.
///
/// [tolerance] extends the reach around a room, in plan units, so a room drawn
/// smaller than a fingertip stays usable. It must shrink as the map is zoomed
/// in — a finger then covers fewer plan units — which is the caller's job.
///
/// The rules, in order:
///
///  * a tap **inside** a room wins over any nearby one, however close;
///  * among rooms containing the point, the **smallest** wins, so a cupboard
///    drawn inside a hall is selectable at all;
///  * otherwise the **nearest** room within [tolerance] wins, so two neighbours
///    never both claim the same tap;
///  * nothing within reach means nothing is selected. Empty floor is a real
///    answer, not a reason to guess.
MapRoomGeometry? hitTestRoom(
  Iterable<MapRoomGeometry> rooms,
  Offset point, {
  double tolerance = 0,
}) {
  MapRoomGeometry? contained;
  double containedArea = double.infinity;

  MapRoomGeometry? nearest;
  double nearestDistance = double.infinity;

  for (final MapRoomGeometry room in rooms) {
    final Rect bounds = room.bounds;
    final double area = bounds.width * bounds.height;

    if (bounds.contains(point) || _onEdge(bounds, point)) {
      if (area < containedArea) {
        contained = room;
        containedArea = area;
      }
      continue;
    }

    if (tolerance <= 0) continue;
    final double distance = _distanceTo(bounds, point);
    if (distance > tolerance) continue;
    if (distance < nearestDistance ||
        (distance == nearestDistance &&
            area <
                (nearest == null
                    ? double.infinity
                    : nearest.bounds.width * nearest.bounds.height))) {
      nearest = room;
      nearestDistance = distance;
    }
  }

  return contained ?? nearest;
}

/// `Rect.contains` excludes the right and bottom edge; a tap on the wall of a
/// room is still that room.
bool _onEdge(Rect bounds, Offset point) =>
    point.dx >= bounds.left &&
    point.dx <= bounds.right &&
    point.dy >= bounds.top &&
    point.dy <= bounds.bottom;

/// Shortest distance from [point] to [bounds]; zero inside.
double _distanceTo(Rect bounds, Offset point) {
  final double dx = math.max(
    0,
    math.max(bounds.left - point.dx, point.dx - bounds.right),
  );
  final double dy = math.max(
    0,
    math.max(bounds.top - point.dy, point.dy - bounds.bottom),
  );
  return math.sqrt(dx * dx + dy * dy);
}
