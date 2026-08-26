// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'mail_message.dart';

/// Normalises what the user typed into the term the local search matches with.
///
/// Trimmed (a term pasted with leading/trailing spaces still matches) and
/// lower-cased. Dart's `toLowerCase` is Unicode-aware, so `Prüfung` matches
/// `PRÜFUNG` and `Anhalt` matches `anhalt`; no locale-specific collator is
/// needed for the German case rules this search has to cover. `ß`/`ss` are
/// *not* folded into each other — that would need a full case-folding table
/// for a single edge case the server search still covers.
String normalizeMailSearchTerm(String raw) => raw.trim().toLowerCase();

/// True when any of [fields] contains [term] (which must already be
/// normalised). Null and blank fields simply never match.
bool mailTextMatches(Iterable<String?> fields, String term) {
  if (term.isEmpty) return false;
  for (final String? field in fields) {
    if (field == null || field.isEmpty) continue;
    if (field.toLowerCase().contains(term)) return true;
  }
  return false;
}

/// What a header alone can be searched by: sender and subject.
Iterable<String?> mailHeaderSearchFields(MailMessageHeader header) sync* {
  yield header.subject;
  yield header.from.name;
  yield header.from.email;
}

/// What a cached full message can be searched by: sender, recipients, subject
/// and the (already plain-text) body. Attachment bytes are never searched.
Iterable<String?> mailDetailSearchFields(MailMessageDetail detail) sync* {
  yield detail.subject;
  yield detail.body;
  for (final MailAddress address in <MailAddress>[
    detail.from,
    ...detail.to,
    ...detail.cc,
  ]) {
    yield address.name;
    yield address.email;
  }
}
