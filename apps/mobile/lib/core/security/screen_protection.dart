// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Keeps a screen out of screenshots and the OS app-switcher preview.
///
/// Selective by decision, not global: the screens that ask for this are the
/// ones showing a university password or the copy of a student ID. A timetable,
/// a canteen menu or a news article stays perfectly screenshottable — students
/// share those on purpose, and locking the whole app down would take that away
/// to protect screens that do not need it.
///
/// What each platform actually does differs, and the difference is real:
///
/// * **Android** sets `FLAG_SECURE`, which blocks screenshots *and* blanks the
///   Recents thumbnail.
/// * **iOS** has no equivalent. It covers the window while the app is
///   inactive, which is the moment the switcher snapshot is taken. Screenshots
///   themselves stay possible there.
///
/// Nothing else is claimed: this is not a defence against a rooted device, a
/// screen recorder with system privileges, or someone with the phone in hand.
class ScreenProtection {
  const ScreenProtection([this._channel = _defaultChannel]);

  static const MethodChannel _defaultChannel = MethodChannel(
    'dev.erikengler.campuskoethen/screen_protection',
  );

  final MethodChannel _channel;

  /// Whether the platform under this build implements the channel at all.
  ///
  /// Only Android and iOS carry the native side. On anything else — a widget
  /// test, a desktop build — the calls would throw `MissingPluginException`
  /// on every screen that asks for protection.
  static bool get isSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Asks for protection. Reference-counted on the native side, so nested
  /// protected screens cannot uncover each other.
  Future<void> acquire() => _invoke('acquire');

  /// Gives up one request.
  Future<void> release() => _invoke('release');

  Future<void> _invoke(String method) async {
    if (!isSupported) return;
    try {
      await _channel.invokeMethod<void>(method);
    } on MissingPluginException {
      // An older build of the host app without the native side. Failing the
      // screen over a missing privacy nicety would be the worse trade.
      assert(() {
        debugPrint('ScreenProtection: channel unavailable ($method).');
        return true;
      }());
    }
  }
}

/// Protects everything below it for as long as it is in the tree.
///
/// Wrapped around a screen's body rather than called from `initState`, so the
/// release is tied to the widget's own lifetime — including a back gesture
/// that is abandoned half way, which never runs a manual `dispose` path.
class ProtectedScreen extends StatefulWidget {
  const ProtectedScreen({
    required this.child,
    this.protection = const ScreenProtection(),
    super.key,
  });

  final Widget child;

  /// Overridable so a widget test can observe the calls.
  final ScreenProtection protection;

  @override
  State<ProtectedScreen> createState() => _ProtectedScreenState();
}

class _ProtectedScreenState extends State<ProtectedScreen> {
  bool _held = false;

  @override
  void initState() {
    super.initState();
    _held = true;
    widget.protection.acquire();
  }

  @override
  void dispose() {
    if (_held) widget.protection.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
