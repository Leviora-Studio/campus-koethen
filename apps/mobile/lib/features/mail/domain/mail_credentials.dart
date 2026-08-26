// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:meta/meta.dart';

/// The inputs the login needs.
///
/// The email address is the IMAP username, the SMTP username AND the sender
/// address. There is intentionally no separate username, login, matrikel or
/// sender-*address* field, and nothing is derived from the address.
///
/// [displayName] is a purely cosmetic personal name that becomes the friendly
/// part of the `From` header (`"Name" <address>`). It is neither a credential
/// nor a second identity: the sender address stays the account address.
///
/// [toString] is overridden to guarantee the password can never leak into a
/// log, an exception, telemetry or a debug dump.
@immutable
class MailCredentials {
  const MailCredentials({
    required this.emailAddress,
    required this.password,
    this.displayName,
  });

  final String emailAddress;
  final String password;
  final String? displayName;

  @override
  bool operator ==(Object other) =>
      other is MailCredentials &&
      other.emailAddress == emailAddress &&
      other.password == password &&
      other.displayName == displayName;

  @override
  int get hashCode => Object.hash(emailAddress, password, displayName);

  /// Deliberately omits the password AND the word "password" so no automatic
  /// string interpolation can ever surface it.
  @override
  String toString() => 'MailCredentials(<redacted> for $emailAddress)';
}

final RegExp _emailPattern = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$');

/// Conservative email check: exactly one `@`, a non-empty local part, and a
/// domain with a dot. Deliberately strict-but-simple rather than a full RFC
/// grammar, which would accept forms no mail server here uses.
bool isValidEmailAddress(String? raw) {
  final String value = (raw ?? '').trim();
  return _emailPattern.hasMatch(value);
}

/// Trims surrounding whitespace only. The local part is case-sensitive per
/// spec, so the address is never lowercased or otherwise rewritten.
String normalizeEmailAddress(String raw) => raw.trim();
