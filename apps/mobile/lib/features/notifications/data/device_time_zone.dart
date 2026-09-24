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

  /// The location to plan in — the device zone, or its current UTC offset
  /// when the platform cannot provide an IANA name. Never throws.
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
    if (name == null) return _deviceOffsetLocation();
    try {
      return tz.getLocation(name);
    } catch (error) {
      // A newly split zone or vendor-specific alias may be absent from the
      // bundled database. The device's current offset is still more accurate
      // than silently scheduling every reminder at UTC.
      _report(error);
      return _deviceOffsetLocation();
    }
  }

  tz.Location _deviceOffsetLocation() {
    final Duration offset = DateTime.now().timeZoneOffset;
    final String name = 'device-offset-${offset.inMinutes}';
    return tz.Location(name, const [], const [], [
      tz.TimeZone(offset, isDst: false, abbreviation: name),
    ]);
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
