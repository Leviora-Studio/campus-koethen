// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../theme/app_colors.dart';
import 'safe_link_launcher.dart';

/// Matches `https://`, `mailto:` and `tel:` occurrences in plain text.
///
/// Only these three schemes are ever handed to [SafeLinkLauncher], so nothing
/// else is worth recognising as a link in the first place.
final RegExp _linkPattern = RegExp(
  r'(https://|mailto:|tel:)\S+',
  caseSensitive: false,
);

/// Trailing characters that are almost never part of a URL but commonly
/// follow one in prose — a sentence-ending period, a closing bracket that
/// opened before the link, and so on.
const String _trimmableTrailers = '.,;:!?)]}>"\'';

/// Renders plain [text] with recognisable `https`/`mailto`/`tel` occurrences
/// turned into activatable links, while the rest stays selectable prose.
///
/// This is the plain-text counterpart to structured `InlineLink` rendering:
/// mail bodies are plain text (see `docs/student-mail.md`), so links inside
/// them have to be found rather than parsed from markup. Only the three
/// [SafeLinkLauncher.allowedSchemes] are ever recognised — everything else in
/// the text stays inert text.
class LinkifiedText extends ConsumerStatefulWidget {
  const LinkifiedText(this.text, {this.style, super.key});

  final String text;
  final TextStyle? style;

  @override
  ConsumerState<LinkifiedText> createState() => _LinkifiedTextState();
}

class _LinkifiedTextState extends ConsumerState<LinkifiedText> {
  /// The text broken into plain runs and links, computed once per text.
  ///
  /// Finding the links is the expensive half of this widget and it depends
  /// only on the text — not on the theme, the locale or anything else a
  /// rebuild can change. A mail body is the longest text in the app, and it
  /// used to be scanned again, with every recognizer thrown away and rebuilt,
  /// on every single build.
  late List<_TextRun> _runs;

  /// One recognizer per link run, alive for as long as the runs are.
  final List<TapGestureRecognizer> _recognizers = <TapGestureRecognizer>[];

  @override
  void initState() {
    super.initState();
    _analyse();
  }

  @override
  void didUpdateWidget(LinkifiedText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) _analyse();
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  void _disposeRecognizers() {
    for (final TapGestureRecognizer recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  void _analyse() {
    _disposeRecognizers();
    _runs = _runsOf(widget.text);
    for (final _TextRun run in _runs) {
      final String? url = run.url;
      if (url == null) continue;
      _recognizers.add(TapGestureRecognizer()..onTap = () => _open(url));
    }
  }

  Future<void> _open(String url) async {
    final LinkLaunchResult result = await ref
        .read(linkLauncherProvider)
        .open(url);
    if (!mounted || result == LinkLaunchResult.opened) return;
    final AppLocalizations l10n = context.l10n;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result == LinkLaunchResult.blocked
              ? l10n.errorLinkBlocked
              : l10n.errorLinkNotOpened,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final TextStyle baseStyle =
        widget.style ?? DefaultTextStyle.of(context).style;
    if (_recognizers.isEmpty) {
      return SelectableText(widget.text, style: baseStyle);
    }

    final AppColors colors = context.colors;
    final TextStyle linkStyle = baseStyle.copyWith(
      color: colors.primary,
      decoration: TextDecoration.underline,
      decorationColor: colors.primary,
      fontWeight: FontWeight.w600,
    );

    // Only the presentation is rebuilt here — which runs there are, and which
    // of them are links, was decided when the text arrived.
    int linkIndex = 0;
    final List<InlineSpan> spans = <InlineSpan>[
      for (final _TextRun run in _runs)
        if (run.url == null)
          TextSpan(text: run.text)
        else
          TextSpan(
            text: run.text,
            style: linkStyle,
            recognizer: _recognizers[linkIndex++],
            mouseCursor: SystemMouseCursors.click,
          ),
    ];

    return SelectableText.rich(TextSpan(children: spans), style: baseStyle);
  }
}

/// A stretch of the text: plain prose, or an activatable link.
@immutable
class _TextRun {
  const _TextRun.plain(this.text) : url = null;
  const _TextRun.link(this.text) : url = text;

  final String text;

  /// The URL to open, or `null` for prose.
  final String? url;
}

/// Splits [text] into prose and links.
///
/// A recognised occurrence whose scheme [SafeLinkLauncher] does not allow is
/// deliberately NOT skipped over: the cursor stays put, so the raw text
/// remains part of the prose around it, exactly as inert text.
List<_TextRun> _runsOf(String text) {
  final List<_TextRun> runs = <_TextRun>[];
  int cursor = 0;
  for (final RegExpMatch match in _linkPattern.allMatches(text)) {
    final String raw = match.group(0)!;
    final int trimEnd = _trimTrailingLength(raw);
    final String candidate = raw.substring(0, trimEnd);
    final String trailer = raw.substring(trimEnd);
    if (!SafeLinkLauncher.isAllowed(candidate)) continue;

    if (match.start > cursor) {
      runs.add(_TextRun.plain(text.substring(cursor, match.start)));
    }
    runs.add(_TextRun.link(candidate));
    if (trailer.isNotEmpty) runs.add(_TextRun.plain(trailer));
    cursor = match.end;
  }
  if (cursor < text.length) runs.add(_TextRun.plain(text.substring(cursor)));
  return runs;
}

/// Length of [raw] with trailing punctuation in [_trimmableTrailers] stripped,
/// so `https://hs-anhalt.de.` at the end of a sentence links to
/// `https://hs-anhalt.de` rather than swallowing the full stop.
int _trimTrailingLength(String raw) {
  int end = raw.length;
  while (end > 0 && _trimmableTrailers.contains(raw[end - 1])) {
    end--;
  }
  return end;
}
