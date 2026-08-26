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
final RegExp _trailingWhitespacePattern = RegExp(r'[ \t]+\n');
final RegExp _excessiveNewlinesPattern = RegExp(r'\n{3,}');

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
  text = text.replaceAll(_trailingWhitespacePattern, '\n');
  text = text.replaceAll(_excessiveNewlinesPattern, '\n\n');
  return text.trim();
}
