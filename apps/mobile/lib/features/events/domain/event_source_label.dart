// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

/// Formats an event source for visual display.
///
/// Post/channel sources use the familiar `@` prefix, while calendar sources
/// keep their editorial name unchanged even when the calendar is linked to a
/// channel. The guard makes the operation idempotent for cached or restored
/// labels that may already be decorated.
String eventSourceDisplayLabel(String label, {required bool isChannelSource}) {
  if (!isChannelSource || label.isEmpty || label.startsWith('@')) return label;
  return '@$label';
}
