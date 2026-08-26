// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import '../../../core/content/content_block.dart';

/// How many lines of the article the collapsed card shows.
const int kNewsPreviewLines = 5;

final Expando<String> _previewTextCache = Expando<String>('newsPreviewText');
final Expando<bool> _unpreviewableBlocksCache = Expando<bool>(
  'newsUnpreviewable',
);

/// Flattens the article's blocks into the plain text of the preview.
///
/// The preview is a **text** preview: it can show what a paragraph, a heading,
/// a quote or a list says, but not an image. Blocks are separated by newlines
/// so the five-line limit counts real lines of the article rather than one
/// endless run-on paragraph.
///
/// Formatting is deliberately dropped here — bold text inside a truncated
/// preview adds nothing, and the expanded card renders the real rich text.
String newsPreviewText(List<ContentBlock> blocks) {
  final String? cached = _previewTextCache[blocks];
  if (cached != null) return cached;
  final List<String> lines = <String>[];
  for (final ContentBlock block in blocks) {
    final String text = _blockText(block);
    if (text.isNotEmpty) lines.add(text);
  }
  final String result = lines.join('\n');
  _previewTextCache[blocks] = result;
  return result;
}

/// Whether anything exists that the text preview cannot represent.
///
/// An article whose body is a single image would otherwise look empty with no
/// way to open it: the preview would be blank and, with nothing to truncate,
/// no "show more" would appear.
bool hasUnpreviewableBlocks(List<ContentBlock> blocks) {
  final bool? cached = _unpreviewableBlocksCache[blocks];
  if (cached != null) return cached;
  final bool result = blocks.any((ContentBlock block) => block is ImageBlock);
  _unpreviewableBlocksCache[blocks] = result;
  return result;
}

/// Whether the collapsed card has anything left to reveal.
///
/// [textOverflows] comes from measuring the preview at its real width — only
/// the layout knows whether five lines were enough.
bool hasMoreToShow({
  required List<ContentBlock> blocks,
  required bool textOverflows,
}) => textOverflows || hasUnpreviewableBlocks(blocks);

String _blockText(ContentBlock block) => switch (block) {
  ParagraphBlock(:final List<InlineNode> children) => _inlineText(children),
  HeadingBlock(:final List<InlineNode> children) => _inlineText(children),
  QuoteBlock(:final List<InlineNode> children) => _inlineText(children),
  ListItemBlock(:final List<InlineNode> children) => _inlineText(children),
  ListBlock(:final List<ListItemBlock> items) =>
    items
        .map((ListItemBlock item) => _inlineText(item.children))
        .where((String text) => text.isNotEmpty)
        .join('\n'),
  // An image has no text. It is what `hasUnpreviewableBlocks` reports.
  ImageBlock() => '',
};

String _inlineText(List<InlineNode> nodes) {
  final StringBuffer buffer = StringBuffer();
  for (final InlineNode node in nodes) {
    switch (node) {
      case InlineText(:final String text):
        buffer.write(text);
      case InlineLink(:final List<InlineText> children):
        // The link's label is part of the sentence; the URL is not.
        for (final InlineText child in children) {
          buffer.write(child.text);
        }
    }
  }
  return buffer.toString().trim();
}
