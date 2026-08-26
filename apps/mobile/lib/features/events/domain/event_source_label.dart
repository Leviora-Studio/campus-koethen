// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

/// Formats an event source for visual display.
///
/// Channels use the familiar `@` prefix, while standalone calendar sources
/// keep their editorial name unchanged. The guard makes the operation
/// idempotent for cached or restored labels that may already be decorated.
String eventSourceDisplayLabel(String label, {required bool isChannel}) {
  if (!isChannel || label.isEmpty || label.startsWith('@')) return label;
  return '@$label';
}
