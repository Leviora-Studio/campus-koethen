// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:cached_network_image/cached_network_image.dart';
import 'package:campus_koethen/core/widgets/remote_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// One image, kept as the very same widget instance across pumps, so a
/// rebuild can only come from a dependency and not from a new widget.
const Widget _image = SizedBox(
  width: 300,
  height: 200,
  child: RemoteImage(url: '/v1/media/uploads/artikel.png'),
);

Widget _app({double devicePixelRatio = 2, double textScale = 1}) => MaterialApp(
  home: MediaQuery(
    data: MediaQueryData(
      devicePixelRatio: devicePixelRatio,
      textScaler: TextScaler.linear(textScale),
    ),
    child: const Scaffold(body: Center(child: _image)),
  ),
);

CachedNetworkImage _imageOf(WidgetTester tester) =>
    tester.widget<CachedNetworkImage>(find.byType(CachedNetworkImage));

void main() {
  group('RemoteImage', () {
    testWidgets('decodes at the size it is painted at', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_app());

      // 300 logical pixels wide at a ratio of 2.
      expect(_imageOf(tester).memCacheWidth, 600);
    });

    testWidgets('follows a change of the pixel ratio', (
      WidgetTester tester,
    ) async {
      await tester.pumpWidget(_app());
      await tester.pumpWidget(_app(devicePixelRatio: 4));

      expect(_imageOf(tester).memCacheWidth, 1200);
    });

    testWidgets('is left alone when something else about the media query '
        'changes', (WidgetTester tester) async {
      // The news feed can have several images on screen. Reading the whole
      // `MediaQueryData` rebuilt every one of them whenever the text scale,
      // the safe areas or the orientation changed — none of which affects how
      // large the image is decoded.
      await tester.pumpWidget(_app());
      final CachedNetworkImage before = _imageOf(tester);

      await tester.pumpWidget(_app(textScale: 2));

      expect(
        identical(_imageOf(tester), before),
        isTrue,
        reason: 'a text scale change must not rebuild the image',
      );
    });
  });
}
