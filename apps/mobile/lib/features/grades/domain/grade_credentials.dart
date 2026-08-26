// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:meta/meta.dart';

/// HIS-QIS login credentials. The username is the portal login; there is no
/// derived identifier.
///
/// [toString] never exposes the password — nothing may leak it into a log, an
/// exception, telemetry or a debug dump.
@immutable
class GradeCredentials {
  const GradeCredentials({required this.username, required this.password});

  final String username;
  final String password;

  @override
  bool operator ==(Object other) =>
      other is GradeCredentials &&
      other.username == username &&
      other.password == password;

  @override
  int get hashCode => Object.hash(username, password);

  @override
  String toString() => 'GradeCredentials(<redacted> for $username)';
}

/// Trims surrounding whitespace; the login is otherwise used verbatim.
String normalizeUsername(String raw) => raw.trim();

bool isValidUsername(String? raw) => (raw ?? '').trim().isNotEmpty;

bool isValidPassword(String? raw) => (raw ?? '').isNotEmpty;
