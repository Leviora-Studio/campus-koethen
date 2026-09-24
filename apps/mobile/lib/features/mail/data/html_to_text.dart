// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

final RegExp _scriptStylePattern = RegExp(
  r'<(script|style)[^>]*>.*?</\1>',
  dotAll: true,
  caseSensitive: false,
);
final RegExp _brPattern = RegExp(r'<\s*br\s*/?>', caseSensitive: false);
final RegExp _blockClosePattern = RegExp(
  r'</\s*(p|div|tr|li|h[1-6])\s*>',
  caseSensitive: false,
);
final RegExp _allTagsPattern = RegExp(r'<[^>]+>');
final RegExp _lineWhitespacePattern = RegExp(r'[ \t]+$', multiLine: true);
final RegExp _blankLinesPattern = RegExp(r'\n[ \t]*\n(?:[ \t]*\n)+');

/// Keeps paragraph breaks while removing transport line endings and excess
/// whitespace from both plain and HTML-derived mail bodies.
String normalizeMailBody(String text) => text
    .replaceAll('\r\n', '\n')
    .replaceAll('\r', '\n')
    .replaceAll('\u00a0', ' ')
    .replaceAll(_lineWhitespacePattern, '')
    .replaceAll(_blankLinesPattern, '\n\n')
    .trim();

/// Reduces an HTML mail body to safe plain text.
///
/// This is intentionally lossy: the MVP renders TEXT only. No HTML is shown, no
/// WebView is used, and — because the output is plain text — no remote image is
/// ever fetched. Scripts, styles and tags are removed rather than interpreted.
String htmlToPlainText(String? html) {
  if (html == null || html.trim().isEmpty) return '';
  String text = html;
  // Drop script/style blocks entirely, including their content.
  text = text.replaceAll(_scriptStylePattern, ' ');
  // Turn common block/line breaks into newlines before stripping tags.
  text = text.replaceAll(_brPattern, '\n');
  text = text.replaceAll(_blockClosePattern, '\n');
  // Remove all remaining tags.
  text = text.replaceAll(_allTagsPattern, '');
  // Decode the handful of entities worth handling.
  text = text
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'");
  // Collapse excessive blank lines and trailing whitespace.
  return normalizeMailBody(text);
}
