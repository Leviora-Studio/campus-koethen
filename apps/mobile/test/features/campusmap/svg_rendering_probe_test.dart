// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

/// Verifies that the renderer actually understands the generated plan.
///
/// The canonical drawing styles rooms through a `<style>` block with CSS class
/// selectors, which `flutter_svg` does NOT support — it logs "unhandled element
/// <style/>" and drops the whole stylesheet, leaving every room unstyled while
/// every other test still passes. The generator therefore inlines the styles,
/// and this test is what keeps that guarantee honest.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

/// Renders [asset] and returns everything the renderer logged while doing so.
Future<List<String>> renderLog(WidgetTester tester, String asset) async {
  final List<String> messages = <String>[];
  final DebugPrintCallback original = debugPrint;
  debugPrint = (String? message, {int? wrapWidth}) {
    if (message != null) messages.add(message);
  };

  try {
    await tester.pumpWidget(MaterialApp(home: SvgPicture.asset(asset)));
    await tester.pumpAndSettle();
  } finally {
    debugPrint = original;
  }
  return messages;
}

void expectNoUnhandled(WidgetTester tester, List<String> messages) {
  expect(tester.takeException(), isNull);
  final Iterable<String> unhandled = messages.where(
    (String message) => message.contains('unhandled element'),
  );
  expect(
    unhandled,
    isEmpty,
    reason:
        'the generated asset must not contain constructs the renderer drops: '
        '${unhandled.join(', ')}',
  );
}

void main() {
  testWidgets('all real floor plans render without unsupported constructs', (
    WidgetTester tester,
  ) async {
    for (final String asset in <String>[
      'assets/maps/ratke-gebaeude/ground-floor.svg',
      'assets/maps/ratke-gebaeude/first-floor.svg',
      'assets/maps/koethen-01/basement.svg',
      'assets/maps/koethen-01/first-floor.svg',
      'assets/maps/koethen-01/second-floor.svg',
      'assets/maps/koethen-01/third-floor.svg',
      'assets/maps/koethen-01/roof.svg',
      'assets/maps/koethen-02/basement.svg',
      'assets/maps/koethen-02/ground-floor.svg',
      'assets/maps/koethen-02/first-floor.svg',
      'assets/maps/koethen-02/second-floor.svg',
      'assets/maps/koethen-03/ground-floor.svg',
      'assets/maps/koethen-03/first-floor.svg',
      'assets/maps/koethen-03/second-floor.svg',
    ]) {
      expectNoUnhandled(tester, await renderLog(tester, asset));
    }
  });
}
