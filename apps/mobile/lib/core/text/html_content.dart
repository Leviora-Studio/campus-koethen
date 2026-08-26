// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:html/dom.dart';
import 'package:html/parser.dart' as html;

final RegExp _horizontalWhitespace = RegExp(r'[ \t]+');
final RegExp _newlineWithSpaces = RegExp(r' *\n *');
final RegExp _excessiveNewlines = RegExp(r'\n{3,}');

/// Reduces untrusted HTML (e.g. Moodle course/module descriptions and forum
/// posts) to safe plain text.
///
/// A real DOM parse (not regex) that removes `<script>`/`<style>` entirely and
/// keeps only the text — the safest possible rendered subset. No script ever
/// runs, and no markup reaches the UI. HTML entities are decoded, whitespace is
/// collapsed and paragraph breaks are preserved.
String htmlToSafeText(String? source) {
  if (source == null || source.trim().isEmpty) return '';
  final String text;
  if (!source.contains('<') && !source.contains('&')) {
    text = source;
  } else {
    final DocumentFragment fragment = html.parseFragment(source);
    for (final Element node in fragment.querySelectorAll('script, style')) {
      node.remove();
    }
    // Turn block boundaries into newlines before flattening to text.
    for (final Element node in fragment.querySelectorAll(
      'br, p, div, li, tr, h1, h2, h3, h4',
    )) {
      node.append(Text('\n'));
    }
    text = fragment.text ?? '';
  }
  return text
      .replaceAll(' ', ' ')
      .replaceAll(_horizontalWhitespace, ' ')
      .replaceAll(_newlineWithSpaces, '\n')
      .replaceAll(_excessiveNewlines, '\n\n')
      .trim();
}

/// The `href` targets of every link in [source], in document order.
///
/// Reducing HTML to plain text is the right call — no WebView, no remote
/// images, no script — but it also silently threw away every URL, so a Moodle
/// announcement reading "details here: <a href="…">link</a>" arrived as
/// "details here: link" with the destination gone for good.
///
/// Only `http`/`https` absolute URLs survive: a `javascript:` or `data:`
/// target is exactly the kind of thing this module exists to drop, and a
/// relative path has no meaning outside the page it came from. Duplicates are
/// removed, order is kept.
List<String> htmlLinkTargets(String? source) {
  if (source == null || !source.contains('<')) return const <String>[];
  final DocumentFragment fragment = html.parseFragment(source);
  for (final Element node in fragment.querySelectorAll('script, style')) {
    node.remove();
  }
  final List<String> targets = <String>[];
  final Set<String> seen = <String>{};
  for (final Element anchor in fragment.querySelectorAll('a[href]')) {
    final String href = (anchor.attributes['href'] ?? '').trim();
    if (href.isEmpty) continue;
    final Uri? uri = Uri.tryParse(href);
    if (uri == null || !uri.hasScheme) continue;
    if (uri.scheme != 'http' && uri.scheme != 'https') continue;
    if (seen.add(href)) targets.add(href);
  }
  return List<String>.unmodifiable(targets);
}
