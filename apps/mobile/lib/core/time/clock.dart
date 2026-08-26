// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

/// An injectable time source, so time-dependent logic (e.g. rolling 24-hour
/// sync windows) can be tested with a controllable clock instead of the wall
/// clock.
abstract interface class Clock {
  DateTime now();
}

/// The real clock used in production.
class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now();
}
