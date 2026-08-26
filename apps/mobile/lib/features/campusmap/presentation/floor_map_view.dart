// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../../../core/theme/app_dimensions.dart';
import '../../../l10n/l10n.dart';
import '../domain/map_catalog.dart';
import '../domain/map_hit_test.dart';

/// The zoomable floor plan.
///
/// The SVG is a bundled, generated asset — never anything fetched or
/// manipulated at runtime. The selection highlight is drawn as an overlay in
/// plan coordinates rather than by editing the SVG, which keeps the asset
/// immutable and the highlight themable.
///
/// The highlight deliberately uses THREE cues, not just colour: a thick
/// outline, a marker above the room, and a textual statement of the selection
/// outside the map (see [CampusMapScreen]).
///
/// Rooms are tappable. The hit test runs against the bundled geometry, not
/// against the SVG: the asset is a picture, and treating it as a document to
/// query would tie the app to how the generator happens to emit it.
/// How far the map may zoom in **by itself** when a room is selected.
///
/// Selecting a room answers "where is this room" — and a close-up of the room
/// alone, without the corridor, the neighbouring numbers or the stairs, is the
/// worst possible answer. So the map never zooms in on its own at all: the
/// selection keeps the overview, or whatever zoom the user chose themselves.
/// Pinching past this stays possible — this caps what happens unasked.
const double kMaxFocusScale = 1.0;

class FloorMapView extends StatefulWidget {
  const FloorMapView({
    required this.floor,
    required this.rooms,
    required this.selected,
    this.onRoomTap,
    this.visiblePadding = EdgeInsets.zero,
    super.key,
  });

  final MapFloor floor;

  /// The geometry of **this floor**. The caller filters; a room one storey up
  /// must never answer a tap.
  final List<MapRoomGeometry> rooms;

  final MapRoomGeometry? selected;

  /// Called with the room key when a room is tapped. A tap on empty floor does
  /// nothing at all.
  final ValueChanged<String>? onRoomTap;

  /// How much of the view is covered by overlays — the search bar above and the
  /// detail sheet below.
  ///
  /// The map is full-bleed on purpose, so parts of it sit behind those panels.
  /// Focusing on the geometric centre would push the selected room underneath
  /// one of them; the focus therefore targets the centre of what is actually
  /// visible.
  final EdgeInsets visiblePadding;

  @override
  State<FloorMapView> createState() => FloorMapViewState();
}

class FloorMapViewState extends State<FloorMapView> {
  final TransformationController _controller = TransformationController();

  /// Scale factor from plan units to laid-out pixels; set by the layout pass.
  double _planScale = 1;
  Size _viewport = Size.zero;

  @override
  void didUpdateWidget(FloorMapView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selected?.roomKey != widget.selected?.roomKey ||
        oldWidget.floor.floorKey != widget.floor.floorKey ||
        oldWidget.visiblePadding != widget.visiblePadding) {
      // Focus after layout so the viewport size is known.
      WidgetsBinding.instance.addPostFrameCallback((_) => _focusSelection());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  /// Scale from plan units to laid-out pixels. Exposed for the focus test.
  @visibleForTesting
  double get planScale => _planScale;

  /// The transform currently applied to the plan. Exposed for the focus test.
  @visibleForTesting
  Matrix4 get currentTransform => _controller.value;

  /// Where the plan's top-left corner sits inside the viewport.
  ///
  /// The plan is laid out inside a [Center], so whenever it does not fill the
  /// viewport it is offset — and focusing in plain plan coordinates would then
  /// land next to the intended room instead of on it.
  Offset get _planOrigin {
    final Rect viewBox = widget.floor.viewBox;
    final Size planSize = Size(
      viewBox.width * _planScale,
      viewBox.height * _planScale,
    );
    return Offset(
      math.max(0, (_viewport.width - planSize.width) / 2),
      math.max(0, (_viewport.height - planSize.height) / 2),
    );
  }

  /// Brings the selected room into the uncovered part of the viewport.
  ///
  /// Never by zooming: the zoom stays exactly where the user left it, and a
  /// room that is already in view is left alone entirely. Only a room hidden
  /// behind the search bar, the detail sheet or the edge of the screen is
  /// panned into sight.
  void _focusSelection() {
    if (!mounted || _viewport.isEmpty) return;
    final MapRoomGeometry? room = widget.selected;
    if (room == null) {
      resetView();
      return;
    }

    // The part of the view that is not covered by the overlays.
    final Rect visible = visibleRect;
    if (visible.width <= 0 || visible.height <= 0) return;

    final double scale = math.max(
      _controller.value.getMaxScaleOnAxis(),
      kMaxFocusScale,
    );

    // The room's focus point expressed in the InteractiveViewer's CHILD
    // coordinates, i.e. including the centring offset.
    final Offset centre =
        _planOrigin +
        Offset(room.focus.dx * _planScale, room.focus.dy * _planScale);

    // Already somewhere the user can see it: moving the map now would be an
    // unasked-for jump, not help.
    final Offset current = MatrixUtils.transformPoint(
      _controller.value,
      centre,
    );
    if (visible.contains(current)) return;

    final Offset target = _clampToViewer(
      Offset(
        visible.center.dx - centre.dx * scale,
        visible.center.dy - centre.dy * scale,
      ),
      scale,
    );

    setState(() {
      _controller.value = Matrix4.identity()
        ..translateByDouble(target.dx, target.dy, 0, 1)
        ..scaleByDouble(scale, scale, 1, 1);
    });
  }

  /// Limits a translation to what [InteractiveViewer] itself would allow.
  ///
  /// The viewer's child fills the viewport, so panning may never expose
  /// anything beside it — at overview zoom that leaves no freedom at all.
  /// Writing a transform past that limit does not widen it: the viewer simply
  /// discards the excess on the next gesture, so the map would sit off-centre
  /// with part of the floor cut off and snap back the moment the user drags.
  /// Clamping here keeps what is shown and what is reachable the same thing.
  Offset _clampToViewer(Offset translation, double scale) {
    final double minX = _viewport.width * (1 - scale);
    final double minY = _viewport.height * (1 - scale);
    return Offset(
      translation.dx.clamp(math.min(minX, 0), 0),
      translation.dy.clamp(math.min(minY, 0), 0),
    );
  }

  /// The uncovered area of the view, in viewport coordinates.
  @visibleForTesting
  Rect get visibleRect {
    final EdgeInsets pad = widget.visiblePadding;
    return Rect.fromLTRB(
      pad.left,
      pad.top,
      _viewport.width - pad.right,
      _viewport.height - pad.bottom,
    );
  }

  /// Back to the whole floor.
  void resetView() {
    if (!mounted) return;
    setState(() => _controller.value = Matrix4.identity());
  }

  /// Turns a tap into a room, or into nothing.
  ///
  /// [local] arrives in the coordinates of the plan **child**, because the
  /// detector sits inside the [InteractiveViewer]'s child: Flutter has already
  /// mapped the pointer through the current pan and zoom. That is why this
  /// keeps working after zooming and dragging, and why it needs no arithmetic
  /// of its own to undo the transform.
  void _handleTap(Offset local) {
    final ValueChanged<String>? onRoomTap = widget.onRoomTap;
    if (onRoomTap == null || _planScale <= 0) return;

    // A fingertip is roughly 24 logical pixels across. Zoomed in, those pixels
    // cover fewer plan units, so the reach around a small room has to shrink
    // with the zoom — otherwise a magnified plan would get less precise the
    // closer you looked.
    final double zoom = _controller.value.getMaxScaleOnAxis();
    final double tolerance = 12 / (_planScale * (zoom <= 0 ? 1 : zoom));

    final MapRoomGeometry? room = hitTestRoom(
      widget.rooms,
      local / _planScale,
      tolerance: tolerance,
    );
    if (room != null) onRoomTap(room.roomKey);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final Rect viewBox = widget.floor.viewBox;

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final double scale = math.min(
          constraints.maxWidth / viewBox.width,
          constraints.maxHeight / viewBox.height,
        );
        final Size planSize = Size(
          viewBox.width * scale,
          viewBox.height * scale,
        );

        // Remembered for focusing; the callback runs outside the build phase.
        if (_planScale != scale || _viewport != constraints.biggest) {
          _planScale = scale;
          _viewport = constraints.biggest;
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (widget.selected != null) _focusSelection();
          });
        }

        return Semantics(
          label: l10n.campusMapSemanticMap,
          child: ClipRect(
            child: InteractiveViewer(
              transformationController: _controller,
              minScale: 1,
              maxScale: 8,
              child: Center(
                child: SizedBox(
                  width: planSize.width,
                  height: planSize.height,
                  // Inside the transformed child on purpose: the tap arrives in
                  // plan coordinates whatever the pan and zoom are.
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (TapUpDetails details) =>
                        _handleTap(details.localPosition),
                    child: Stack(
                      fit: StackFit.expand,
                      children: <Widget>[
                        // The plan is the expensive, rarely-changing layer;
                        // isolating it in its own boundary keeps the small,
                        // frequently-changing selection overlay from forcing
                        // a repaint of the whole floor plan.
                        RepaintBoundary(
                          child: SvgPicture.asset(
                            widget.floor.svgAsset,
                            fit: BoxFit.fill,
                            // The plan is decorative here; the textual room
                            // details outside the map carry the information, and
                            // the accessible way to pick a room is the search.
                            excludeFromSemantics: true,
                          ),
                        ),
                        if (widget.selected != null)
                          RepaintBoundary(
                            child: CustomPaint(
                              painter: _SelectionPainter(
                                room: widget.selected!,
                                planScale: scale,
                                color: Theme.of(context).colorScheme.primary,
                                onColor: Theme.of(
                                  context,
                                ).colorScheme.onPrimary,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Draws the selection highlight in plan coordinates.
class _SelectionPainter extends CustomPainter {
  const _SelectionPainter({
    required this.room,
    required this.planScale,
    required this.color,
    required this.onColor,
  });

  final MapRoomGeometry room;
  final double planScale;
  final Color color;

  /// Contrast colour for the marker centre; comes from the theme so the
  /// highlight stays legible in both light and dark mode.
  final Color onColor;

  @override
  void paint(Canvas canvas, Size size) {
    final Rect rect = Rect.fromLTWH(
      room.bounds.left * planScale,
      room.bounds.top * planScale,
      room.bounds.width * planScale,
      room.bounds.height * planScale,
    );
    final RRect rounded = RRect.fromRectAndRadius(
      rect.deflate(1),
      const Radius.circular(AppRadius.card),
    );

    // A translucent wash makes the room readable without hiding its label…
    canvas.drawRRect(
      rounded,
      Paint()
        ..style = PaintingStyle.fill
        ..color = color.withValues(alpha: 0.22),
    );
    // …and a heavy outline carries the state without relying on colour alone.
    canvas.drawRRect(
      rounded,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 4
        ..color = color,
    );

    // A marker above the room: a third, shape-based cue.
    final Offset tip = Offset(rect.center.dx, rect.top);
    final Path marker = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(tip.dx - 9, tip.dy - 14)
      ..lineTo(tip.dx + 9, tip.dy - 14)
      ..close();
    canvas.drawPath(marker, Paint()..color = color);
    canvas.drawCircle(Offset(tip.dx, tip.dy - 20), 9, Paint()..color = color);
    canvas.drawCircle(Offset(tip.dx, tip.dy - 20), 4, Paint()..color = onColor);
  }

  @override
  bool shouldRepaint(_SelectionPainter oldDelegate) =>
      oldDelegate.room.roomKey != room.roomKey ||
      oldDelegate.planScale != planScale ||
      oldDelegate.color != color ||
      oldDelegate.onColor != onColor;
}
