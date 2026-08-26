// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:campus_koethen/core/security/screen_protection.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Records the calls that would reach the platform.
class _RecordingChannel extends MethodChannel {
  _RecordingChannel() : super('test/screen_protection');

  final List<String> calls = <String>[];

  @override
  Future<T?> invokeMethod<T>(String method, [dynamic arguments]) async {
    calls.add(method);
    return null;
  }
}

void main() {
  // The widget test platform is Android by default, so `isSupported` is true
  // and the calls really are attempted.
  testWidgets('acquires while mounted and releases on dispose', (
    WidgetTester tester,
  ) async {
    final _RecordingChannel channel = _RecordingChannel();
    final ScreenProtection protection = ScreenProtection(channel);

    await tester.pumpWidget(
      ProtectedScreen(protection: protection, child: const SizedBox.shrink()),
    );
    expect(channel.calls, <String>['acquire']);

    // Replacing the tree disposes the state — the same thing a pop does.
    await tester.pumpWidget(const SizedBox.shrink());
    expect(channel.calls, <String>['acquire', 'release']);
  });

  testWidgets('a rebuild does not acquire a second time', (
    WidgetTester tester,
  ) async {
    // Otherwise the native counter would climb on every rebuild and the
    // protection would never drop again.
    final _RecordingChannel channel = _RecordingChannel();
    final ScreenProtection protection = ScreenProtection(channel);

    for (int i = 0; i < 3; i++) {
      await tester.pumpWidget(
        ProtectedScreen(
          protection: protection,
          child: SizedBox(width: 10.0 + i),
        ),
      );
    }
    expect(channel.calls, <String>['acquire']);
  });

  testWidgets('nested protected screens each hold their own request', (
    WidgetTester tester,
  ) async {
    final _RecordingChannel channel = _RecordingChannel();
    final ScreenProtection protection = ScreenProtection(channel);

    await tester.pumpWidget(
      ProtectedScreen(
        protection: protection,
        child: ProtectedScreen(
          protection: protection,
          child: const SizedBox.shrink(),
        ),
      ),
    );
    // Two acquires: the counter on the native side is what stops the inner
    // screen's disposal from uncovering the outer one.
    expect(channel.calls, <String>['acquire', 'acquire']);

    await tester.pumpWidget(const SizedBox.shrink());
    expect(channel.calls, <String>['acquire', 'acquire', 'release', 'release']);
  });
}
