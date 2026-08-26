// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:flutter/foundation.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

/// Resolves the zone the device is in, so a wall-clock time can be planned as
/// a wall-clock time.
///
/// A port: the planner is a pure function over a [tz.Location], and a test can
/// hand it Berlin, Sydney or a zone whose clocks change on the day under test
/// without touching a platform channel.
abstract interface class TimeZoneResolver {
  /// Loads the zone database once. Safe to call repeatedly.
  Future<void> initialize();

  /// The current IANA zone name, e.g. `Europe/Berlin`, or `null` when the
  /// platform will not say.
  Future<String?> deviceTimeZoneName();

  /// The location to plan in — the device zone, or UTC when it cannot be
  /// resolved. Never throws: a reminder in the wrong zone is a bug, an app
  /// that will not start is worse.
  Future<tz.Location> resolveLocation();
}

/// [TimeZoneResolver] over `flutter_timezone` and the `timezone` database.
class DeviceTimeZoneResolver implements TimeZoneResolver {
  bool _databaseLoaded = false;

  @override
  Future<void> initialize() async {
    if (_databaseLoaded) return;
    tz_data.initializeTimeZones();
    _databaseLoaded = true;
  }

  @override
  Future<String?> deviceTimeZoneName() async {
    try {
      final TimezoneInfo info = await FlutterTimezone.getLocalTimezone();
      return info.identifier;
    } catch (error) {
      _report(error);
      return null;
    }
  }

  @override
  Future<tz.Location> resolveLocation() async {
    await initialize();
    final String? name = await deviceTimeZoneName();
    if (name == null) return tz.UTC;
    try {
      return tz.getLocation(name);
    } catch (error) {
      // An IANA name the bundled database does not know — a newly split zone,
      // or a vendor-specific alias. UTC is wrong by a whole offset, but it is
      // deterministic, and the alternative is no notifications at all.
      _report(error);
      return tz.UTC;
    }
  }

  void _report(Object error) {
    assert(() {
      debugPrint(
        'notifications: time zone lookup failed (${error.runtimeType})',
      );
      return true;
    }());
  }
}

/// A [TimeZoneResolver] pinned to one zone. For tests, and for any platform
/// without a device zone to ask for.
class FixedTimeZoneResolver implements TimeZoneResolver {
  FixedTimeZoneResolver(this.name);

  final String name;

  @override
  Future<void> initialize() async => tz_data.initializeTimeZones();

  @override
  Future<String?> deviceTimeZoneName() async => name;

  @override
  Future<tz.Location> resolveLocation() async {
    await initialize();
    try {
      return tz.getLocation(name);
    } catch (_) {
      return tz.UTC;
    }
  }
}
