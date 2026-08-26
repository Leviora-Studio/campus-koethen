// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

/// Parses a grade value that may use either decimal separator: HIS-QIS (legacy)
/// uses a comma (`1,7`), HISinOne uses a dot (`1.7`). Both portals' HTML is
/// accepted by every parser, so a portal migration never has to touch this.
double? parseGradeDecimal(String raw) {
  final String trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  return double.tryParse(trimmed.replaceAll(',', '.'));
}
