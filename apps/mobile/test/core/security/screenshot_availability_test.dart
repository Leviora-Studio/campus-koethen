// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

/// Guards the product decision that every screen remains capturable.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

List<File> _productionDartFiles() => Directory('lib')
    .listSync(recursive: true)
    .whereType<File>()
    .where((File file) => file.path.endsWith('.dart'))
    .toList(growable: false);

List<File> _sourceFiles(String path, Set<String> extensions) => Directory(path)
    .listSync(recursive: true)
    .whereType<File>()
    .where(
      (File file) => extensions.any((String ext) => file.path.endsWith(ext)),
    )
    .toList(growable: false);

void main() {
  test('Flutter never requests screenshot protection', () {
    const List<String> forbidden = <String>[
      'ProtectedScreen',
      'ScreenProtection',
      'screen_protection',
    ];
    final List<String> offenders = <String>[];

    for (final File file in _productionDartFiles()) {
      final String source = file.readAsStringSync();
      for (final String marker in forbidden) {
        if (source.contains(marker)) offenders.add('${file.path}: $marker');
      }
    }

    expect(
      offenders,
      isEmpty,
      reason:
          'Every app screen must remain available to screenshots:\n'
          '${offenders.join('\n')}',
    );
  });

  test('Android never enables a secure window', () {
    final List<String> offenders = <String>[];
    for (final File file in _sourceFiles('android/app/src', <String>{
      '.java',
      '.kt',
      '.xml',
    })) {
      final String source = file.readAsStringSync();
      for (final String marker in <String>[
        'FLAG_SECURE',
        'screen_protection',
      ]) {
        if (source.contains(marker)) offenders.add('${file.path}: $marker');
      }
    }

    expect(offenders, isEmpty, reason: offenders.join('\n'));
  });

  test('iOS never installs a capture or app-switcher cover', () {
    final String project = File(
      'ios/Runner.xcodeproj/project.pbxproj',
    ).readAsStringSync();
    final List<String> offenders = <String>[];
    for (final File file in _sourceFiles('ios/Runner', <String>{
      '.swift',
      '.m',
      '.mm',
    })) {
      final String source = file.readAsStringSync();
      for (final String marker in <String>[
        'ScreenProtection',
        'capturedDidChangeNotification',
        'isCaptured',
        'userDidTakeScreenshotNotification',
      ]) {
        if (source.contains(marker)) offenders.add('${file.path}: $marker');
      }
    }

    expect(File('ios/Runner/ScreenProtection.swift').existsSync(), isFalse);
    expect(offenders, isEmpty, reason: offenders.join('\n'));
    expect(project, isNot(contains('ScreenProtection.swift')));
  });

  test('no screenshot-blocking plugin is declared', () {
    final String pubspec = File('pubspec.yaml').readAsStringSync();
    for (final String package in <String>[
      'flutter_windowmanager',
      'screen_protector',
      'secure_application',
    ]) {
      expect(pubspec, isNot(contains(package)), reason: package);
    }
  });
}
