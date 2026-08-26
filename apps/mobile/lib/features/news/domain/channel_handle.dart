// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

final RegExp _invalidChars = RegExp('[^a-z0-9-]');
final RegExp _multipleHyphens = RegExp('-{2,}');
final RegExp _edgeHyphens = RegExp(r'^-+|-+$');

/// Turns a channel name into the handle the feed shows under an article.
///
/// The rules, in order:
///
/// * lower case;
/// * umlauts and ß spelled out (`ä` → `ae`), so a handle stays typable and
///   readable on any keyboard;
/// * common Latin diacritics folded to their base letter;
/// * spaces **removed**, not replaced — "FSR INS" is one word, `@fsrins`;
/// * existing hyphens kept — "FB5-News" is `@fb5-news`;
/// * everything else dropped;
/// * an `@` in front.
///
/// A name that survives none of this yields `null` rather than a bare `@`: a
/// handle with nothing after the sigil says less than showing no handle at all.
String? channelHandle(String name) {
  final StringBuffer folded = StringBuffer();
  for (final int rune in name.toLowerCase().runes) {
    switch (rune) {
      case 0xE4:
        folded.write('ae');
      case 0xF6:
        folded.write('oe');
      case 0xFC:
        folded.write('ue');
      case 0xDF:
        folded.write('ss');
      case 0xE0 || 0xE1 || 0xE2 || 0xE3 || 0xE5:
        folded.write('a');
      case 0xE8 || 0xE9 || 0xEA || 0xEB:
        folded.write('e');
      case 0xEC || 0xED || 0xEE || 0xEF:
        folded.write('i');
      case 0xF2 || 0xF3 || 0xF4 || 0xF5:
        folded.write('o');
      case 0xF9 || 0xFA || 0xFB:
        folded.write('u');
      case 0xE7:
        folded.write('c');
      case 0xF1:
        folded.write('n');
      default:
        folded.writeCharCode(rune);
    }
  }

  final String cleaned = folded
      .toString()
      // Everything that is not a letter, a digit or a hyphen goes — spaces
      // included, which is what merges "FSR INS" into one handle.
      .replaceAll(_invalidChars, '')
      // A name like "— News —" must not leave dangling hyphens.
      .replaceAll(_multipleHyphens, '-')
      .replaceAll(_edgeHyphens, '');

  return cleaned.isEmpty ? null : '@$cleaned';
}

/// The handles of one article's channels, in order and without repeats.
///
/// An article in several channels shows all of them **once** — it is one
/// article, not one per channel.
List<String> channelHandles(Iterable<String> names) {
  final List<String> handles = <String>[];
  final Set<String> seen = <String>{};
  for (final String name in names) {
    final String? handle = channelHandle(name);
    if (handle != null && seen.add(handle)) handles.add(handle);
  }
  return List<String>.unmodifiable(handles);
}
