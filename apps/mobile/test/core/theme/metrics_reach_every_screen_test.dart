// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

/// Holds the design system's promise across the whole app.
///
/// The layout metrics are the one place that decides how much room a screen
/// gives its content. A screen that hardcodes the value instead drifts away
/// from the rest of the app the moment the token changes — which is how
/// contacts, Moodle, mail, grades and to-dos once ended up with a padding
/// nobody could adjust.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Features whose screens must take their padding from the metrics.
const List<String> _features = <String>[
  'contacts',
  'moodle',
  'mail',
  'grades',
  'todos',
  'requests',
];

List<File> _screensOf(String feature) {
  final Directory dir = Directory('lib/features/$feature/presentation');
  if (!dir.existsSync()) return const <File>[];
  return dir
      .listSync(recursive: true)
      .whereType<File>()
      .where((File f) => f.path.endsWith('.dart'))
      .toList();
}

void main() {
  test('no screen hardcodes the outer padding the metrics own', () {
    // `EdgeInsets.all(AppSpacing.lg)` as a scroll view's padding is exactly the
    // value AppMetrics.screenPadding exists to decide.
    final List<String> offenders = <String>[];

    for (final String feature in _features) {
      for (final File file in _screensOf(feature)) {
        final String content = file.readAsStringSync();
        if (content.contains('padding: const EdgeInsets.all(AppSpacing.lg),')) {
          offenders.add(file.path);
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'these screens ignore the layout metrics and should use '
          'context.metrics.screenPadding:\n${offenders.join('\n')}',
    );
  });

  test('the features under test actually exist', () {
    // Guards against the check above passing because a rename made it look at
    // nothing at all.
    for (final String feature in _features) {
      expect(
        _screensOf(feature),
        isNotEmpty,
        reason: 'no screens found for "$feature" — has it moved?',
      );
    }
  });
}
