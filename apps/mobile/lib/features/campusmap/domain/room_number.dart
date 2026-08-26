// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

/// How a room number is compared, in one place.
///
/// Search, mention resolution and ranking all fold numbers the same way — a
/// second spelling of these rules is a second answer to "is this the same
/// room", and the two would drift apart.
library;

final RegExp _separator = RegExp(r'[^\p{L}\p{N}]', unicode: true);
final RegExp _leadingLetters = RegExp(r'^\p{L}+', unicode: true);
final RegExp _numberGroup = RegExp(
  r'^(\p{L}{0,2})[\s.]*(\p{N}{1,4})\s*([/\-–—])\s*(\p{N}{1,4})$',
  unicode: true,
);

/// Folds a room number or query into a comparable form.
///
/// People write `B.201`, `B 201` and `B201` for the same room, so every
/// separator is removed before comparing. Letters are kept as they are, so
/// umlauts still match.
String normalizeRoomQuery(String input) =>
    input.toLowerCase().replaceAll(_separator, '');

/// A normalised number without its building letters: `b202` → `202`.
///
/// Empty when the value carries no digits at all.
String bareRoomNumber(String normalisedNumber) =>
    normalisedNumber.replaceFirst(_leadingLetters, '');

/// Every exact number a grouped room label represents.
///
/// The Ratke directory contains `223–225` and `230/231` as single drawn
/// areas. Keeping one geometry is faithful to the source, while these aliases
/// still let a person search for room `224` or a timetable name room `231`.
/// Ranges are deliberately capped: a typo such as `1-9999` must not allocate
/// thousands of aliases on every catalogue load.
Set<String> roomNumberAliases(String input) {
  final String normalised = normalizeRoomQuery(input);
  if (normalised.isEmpty) return const <String>{};

  final Set<String> aliases = <String>{normalised};
  final RegExpMatch? group = _numberGroup.firstMatch(input.trim());
  if (group == null) return aliases;

  final String prefix = normalizeRoomQuery(group.group(1) ?? '');
  final int? first = int.tryParse(group.group(2)!);
  final int? last = int.tryParse(group.group(4)!);
  if (first == null || last == null) return aliases;

  if (group.group(3) == '/') {
    aliases
      ..add('$prefix$first')
      ..add('$prefix$last');
    return aliases;
  }

  if (last < first || last - first > 20) return aliases;
  for (int number = first; number <= last; number++) {
    aliases.add('$prefix$number');
  }
  return aliases;
}
