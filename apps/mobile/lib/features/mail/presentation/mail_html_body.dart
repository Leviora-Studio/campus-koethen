// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:html/dom.dart' as dom;
import 'package:html/parser.dart' as html;

import '../../../core/links/safe_link_launcher.dart';
import '../../../l10n/l10n.dart';
import '../domain/mail_image_source.dart';
import '../domain/mail_message.dart';

/// Renders the useful parts of an email with Flutter's text and image widgets.
class MailHtmlBody extends ConsumerStatefulWidget {
  const MailHtmlBody({required this.detail, super.key});

  final MailMessageDetail detail;

  @override
  ConsumerState<MailHtmlBody> createState() => _MailHtmlBodyState();
}

class _MailHtmlBodyState extends ConsumerState<MailHtmlBody> {
  static const _ignored = {
    'head',
    'script',
    'style',
    'noscript',
    'iframe',
    'object',
    'embed',
    'template',
    'svg',
    'form',
    'input',
    'button',
    'textarea',
  };
  static const _blocks = {
    'address',
    'blockquote',
    'div',
    'h1',
    'h2',
    'h3',
    'h4',
    'h5',
    'h6',
    'li',
    'p',
    'pre',
    'section',
    'table',
    'tr',
  };
  static final _whiteSpace = RegExp(r'[\t\r\n\f ]+');
  static final _hidden = RegExp(
    r'(?:^|;)\s*(?:display\s*:\s*none|visibility\s*:\s*hidden)',
    caseSensitive: false,
  );

  final _links = <String, TapGestureRecognizer>{};
  late dom.Element? _body = html.parse(widget.detail.html).body;

  @override
  void didUpdateWidget(covariant MailHtmlBody oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.detail.html != oldWidget.detail.html) {
      _body = html.parse(widget.detail.html).body;
      _disposeLinks();
    }
  }

  @override
  void dispose() {
    _disposeLinks();
    super.dispose();
  }

  void _disposeLinks() {
    for (final link in _links.values) {
      link.dispose();
    }
    _links.clear();
  }

  Future<void> _open(String url) async {
    final result = await ref.read(linkLauncherProvider).open(url);
    if (!mounted || result == LinkLaunchResult.opened) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.errorLinkNotOpened)));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spans = <InlineSpan>[];
    bool lineStart = true;
    bool trailingSpace = false;

    void lineBreak() {
      if (!lineStart) spans.add(const TextSpan(text: '\n'));
      lineStart = true;
      trailingSpace = false;
    }

    void write(String text, TextStyle style, String? link) {
      var value = text.replaceAll(_whiteSpace, ' ');
      if (lineStart || trailingSpace) value = value.trimLeft();
      if (value.isEmpty) return;
      spans.add(
        TextSpan(
          text: value,
          style: link == null
              ? style
              : style.copyWith(
                  color: theme.colorScheme.primary,
                  decoration: TextDecoration.underline,
                ),
          recognizer: link == null
              ? null
              : _links.putIfAbsent(
                  link,
                  () => TapGestureRecognizer()..onTap = () => _open(link),
                ),
        ),
      );
      trailingSpace = value.endsWith(' ');
      lineStart = false;
    }

    void visit(dom.Node node, TextStyle style, String? link) {
      if (node is dom.Text) {
        write(node.data, style, link);
        return;
      }
      if (node is! dom.Element) return;
      final tag = node.localName;
      if (_ignored.contains(tag) ||
          node.attributes.containsKey('hidden') ||
          _hidden.hasMatch(node.attributes['style'] ?? '')) {
        return;
      }
      if (tag == 'br' || tag == 'hr') {
        spans.add(const TextSpan(text: '\n'));
        lineStart = true;
        trailingSpace = false;
        return;
      }
      if (tag == 'img') {
        final image = _image(node, link);
        if (image != null) {
          spans.add(WidgetSpan(child: image));
          lineStart = false;
          trailingSpace = false;
        }
        return;
      }
      final block = _blocks.contains(tag);
      if (block) lineBreak();
      if (tag == 'li') write('• ', style, link);
      final elementStyle = switch (tag) {
        'b' || 'strong' || 'th' => style.copyWith(fontWeight: FontWeight.bold),
        'em' || 'i' => style.copyWith(fontStyle: FontStyle.italic),
        'u' => style.copyWith(decoration: TextDecoration.underline),
        'h1' || 'h2' || 'h3' =>
          theme.textTheme.titleMedium!
              .merge(style)
              .copyWith(fontWeight: FontWeight.bold),
        _ => style,
      };
      final href = node.attributes['href'];
      final target = tag == 'a' && SafeLinkLauncher.isAllowed(href)
          ? href
          : link;
      for (final child in node.nodes) {
        visit(child, elementStyle, target);
      }
      if (tag == 'td' || tag == 'th') write(' ', style, link);
      if (block) lineBreak();
    }

    for (final node in _body?.nodes ?? const <dom.Node>[]) {
      visit(node, const TextStyle(), null);
    }
    return Text.rich(
      TextSpan(
        children: spans.isEmpty ? [TextSpan(text: widget.detail.body)] : spans,
      ),
      style: theme.textTheme.bodyLarge,
    );
  }

  Widget? _image(dom.Element element, String? link) {
    final source = element.attributes['src']?.trim() ?? '';
    final id = mailImageContentId(source);
    final bytes = id == null
        ? decodeMailDataImage(source)
        : widget.detail.inlineImages[id];
    final alt = element.attributes['alt']?.trim();
    if (bytes != null) {
      final width = double.tryParse(element.attributes['width'] ?? '');
      final image = Image.memory(
        bytes,
        width: width != null && width.isFinite && width > 0 ? width : null,
        fit: BoxFit.contain,
        semanticLabel: alt,
        errorBuilder: (_, _, _) => Text(alt ?? ''),
      );
      return link == null
          ? image
          : InkWell(onTap: () => _open(link), child: image);
    }
    final uri = Uri.tryParse(source);
    if (uri?.scheme == 'https' && SafeLinkLauncher.isAllowed(source)) {
      return TextButton(
        onPressed: () => _open(source),
        child: Text(
          alt?.isNotEmpty == true ? alt! : context.l10n.mailOpenExternalImage,
        ),
      );
    }
    return alt?.isNotEmpty == true ? Text(alt!) : null;
  }
}
