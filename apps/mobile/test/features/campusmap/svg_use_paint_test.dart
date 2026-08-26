// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

/// Proves that the campus overview's `<defs>` + `<use>` construction is really
/// PAINTED, not merely tolerated.
///
/// The drawing places its trees, parking and assembly-point symbols through
/// local `<use xlink:href="#id">` fragments. A renderer that ignored them would
/// log nothing and throw nothing — the map would simply be missing most of its
/// furniture, and every other test would still pass. The only honest check is
/// to rasterise the asset and compare it with the same drawing stripped of
/// every `<use>`.
///
/// Deliberately a plain `test`, not `testWidgets`: rasterising inside the
/// widget binding hangs until the per-test timeout.
library;

import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

Future<Uint8List> _rasterise(String svg) async {
  final PictureInfo info = await vg.loadPicture(SvgStringLoader(svg), null);
  final ui.Image image = info.picture.toImageSync(437, 225);
  final ByteData? bytes = await image.toByteData(
    format: ui.ImageByteFormat.png,
  );
  return bytes!.buffer.asUint8List();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('the campus overview actually paints its <use> references', () async {
    final String svg = await rootBundle.loadString(
      'assets/maps/campus/koethen-overview.svg',
    );
    expect(
      RegExp(r'<use\b').allMatches(svg).length,
      greaterThan(0),
      reason: 'the fixture for this test is the asset itself',
    );

    final String withoutUse = svg.replaceAll(RegExp(r'<use\b[^>]*/>'), '');
    expect(
      await _rasterise(svg),
      isNot(equals(await _rasterise(withoutUse))),
      reason: '<use> references must contribute to the painted result',
    );
  });
}
