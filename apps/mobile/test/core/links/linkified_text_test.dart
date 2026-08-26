// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:campus_koethen/core/links/linkified_text.dart';
import 'package:campus_koethen/core/links/safe_link_launcher.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import '../../support/pump_app.dart';

class _FakeLauncher implements SafeLinkLauncher {
  _FakeLauncher({this.result = LinkLaunchResult.opened});

  final LinkLaunchResult result;
  final List<String> opened = <String>[];

  @override
  Future<LinkLaunchResult> open(String? rawUrl) async {
    if (rawUrl != null) opened.add(rawUrl);
    return result;
  }
}

/// Finds the recognizer attached to the span whose text is [linkText] inside
/// the single [SelectableText.rich] on screen, then triggers its tap — the
/// same thing a screen-reader activation or a real tap on that glyph run
/// would do.
void _tapLinkSpan(WidgetTester tester, String linkText) {
  final SelectableText widget = tester.widget<SelectableText>(
    find.byType(SelectableText),
  );
  TapGestureRecognizer? found;
  void visit(InlineSpan span) {
    if (span is TextSpan) {
      if (span.text == linkText && span.recognizer is TapGestureRecognizer) {
        found = span.recognizer as TapGestureRecognizer;
      }
      span.children?.forEach(visit);
    }
  }

  visit(widget.textSpan!);
  expect(found, isNotNull, reason: 'no link span for "$linkText"');
  found!.onTap!();
}

void main() {
  group('LinkifiedText', () {
    testWidgets('plain text without a link stays a single selectable text', (
      WidgetTester tester,
    ) async {
      await pumpScreen(
        tester,
        const Scaffold(body: LinkifiedText('Kein Link hier.')),
      );
      await tester.pumpAndSettle();

      expect(find.text('Kein Link hier.'), findsOneWidget);
    });

    testWidgets('an https URL is recognised and opened via the launcher', (
      WidgetTester tester,
    ) async {
      final _FakeLauncher launcher = _FakeLauncher();
      await pumpScreen(
        tester,
        const Scaffold(
          body: LinkifiedText('Siehe https://hs-anhalt.de/mensa für Details.'),
        ),
        overrides: <Override>[linkLauncherProvider.overrideWithValue(launcher)],
      );
      await tester.pumpAndSettle();

      _tapLinkSpan(tester, 'https://hs-anhalt.de/mensa');
      await tester.pumpAndSettle();

      expect(launcher.opened, <String>['https://hs-anhalt.de/mensa']);
      // The rest of the sentence is still on screen as ordinary text.
      expect(find.textContaining('Siehe'), findsOneWidget);
      expect(find.textContaining('für Details.'), findsOneWidget);
    });

    testWidgets('trailing sentence punctuation is not part of the link', (
      WidgetTester tester,
    ) async {
      final _FakeLauncher launcher = _FakeLauncher();
      await pumpScreen(
        tester,
        const Scaffold(body: LinkifiedText('Quelle: https://hs-anhalt.de.')),
        overrides: <Override>[linkLauncherProvider.overrideWithValue(launcher)],
      );
      await tester.pumpAndSettle();

      _tapLinkSpan(tester, 'https://hs-anhalt.de');
      await tester.pumpAndSettle();

      expect(launcher.opened, <String>['https://hs-anhalt.de']);
    });

    testWidgets('a mailto link is recognised and opened', (
      WidgetTester tester,
    ) async {
      final _FakeLauncher launcher = _FakeLauncher();
      await pumpScreen(
        tester,
        const Scaffold(
          body: LinkifiedText('Kontakt: mailto:info@hs-anhalt.de'),
        ),
        overrides: <Override>[linkLauncherProvider.overrideWithValue(launcher)],
      );
      await tester.pumpAndSettle();

      _tapLinkSpan(tester, 'mailto:info@hs-anhalt.de');
      await tester.pumpAndSettle();

      expect(launcher.opened, <String>['mailto:info@hs-anhalt.de']);
    });

    testWidgets('a tel link is recognised and opened', (
      WidgetTester tester,
    ) async {
      final _FakeLauncher launcher = _FakeLauncher();
      await pumpScreen(
        tester,
        const Scaffold(body: LinkifiedText('Ruf an: tel:+493496110')),
        overrides: <Override>[linkLauncherProvider.overrideWithValue(launcher)],
      );
      await tester.pumpAndSettle();

      _tapLinkSpan(tester, 'tel:+493496110');
      await tester.pumpAndSettle();

      expect(launcher.opened, <String>['tel:+493496110']);
    });

    testWidgets('an unsafe scheme is left as inert text', (
      WidgetTester tester,
    ) async {
      final _FakeLauncher launcher = _FakeLauncher();
      await pumpScreen(
        tester,
        const Scaffold(
          body: LinkifiedText('Nicht anklickbar: http://unsicher.example'),
        ),
        overrides: <Override>[linkLauncherProvider.overrideWithValue(launcher)],
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Nicht anklickbar: http://unsicher.example'),
        findsOneWidget,
      );
      expect(launcher.opened, isEmpty);
    });

    testWidgets('a failed open shows a generic error, not the raw URL', (
      WidgetTester tester,
    ) async {
      final _FakeLauncher launcher = _FakeLauncher(
        result: LinkLaunchResult.failed,
      );
      await pumpScreen(
        tester,
        const Scaffold(body: LinkifiedText('https://hs-anhalt.de/kaputt')),
        overrides: <Override>[linkLauncherProvider.overrideWithValue(launcher)],
      );
      await tester.pumpAndSettle();

      _tapLinkSpan(tester, 'https://hs-anhalt.de/kaputt');
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(SnackBar),
          matching: find.text('Der Link konnte nicht geöffnet werden.'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: find.byType(SnackBar),
          matching: find.textContaining('hs-anhalt.de'),
        ),
        findsNothing,
      );
    });

    testWidgets('a rebuild without a text change keeps exactly one link', (
      WidgetTester tester,
    ) async {
      final _FakeLauncher launcher = _FakeLauncher();
      await pumpScreen(
        tester,
        const Scaffold(
          body: LinkifiedText('Mehr unter https://hs-anhalt.de dazu.'),
        ),
        overrides: <Override>[linkLauncherProvider.overrideWithValue(launcher)],
      );
      await tester.pumpAndSettle();

      final String before = _plainText(tester);
      expect(_recognizerCount(tester), 1);

      // Rebuild for a reason that has nothing to do with the text.
      await tester.pump();
      await tester.pumpAndSettle();

      expect(_plainText(tester), before);
      expect(_recognizerCount(tester), 1);

      // The link still works after the rebuild — the recognizer that survived
      // is a live one, not a disposed leftover.
      _tapLinkSpan(tester, 'https://hs-anhalt.de');
      await tester.pumpAndSettle();
      expect(launcher.opened, <String>['https://hs-anhalt.de']);
    });

    testWidgets('a changed text is analysed again', (
      WidgetTester tester,
    ) async {
      final _FakeLauncher launcher = _FakeLauncher();
      await pumpScreen(
        tester,
        const Scaffold(body: _SwitchableText()),
        overrides: <Override>[linkLauncherProvider.overrideWithValue(launcher)],
      );
      await tester.pumpAndSettle();

      // Starts without a link.
      expect(_recognizerCount(tester), 0);

      await tester.tap(find.byType(TextButton));
      await tester.pumpAndSettle();

      expect(_recognizerCount(tester), 1);
      _tapLinkSpan(tester, 'https://hs-anhalt.de');
      await tester.pumpAndSettle();
      expect(launcher.opened, <String>['https://hs-anhalt.de']);

      await tester.tap(find.byType(TextButton));
      await tester.pumpAndSettle();
      expect(_recognizerCount(tester), 0);
    });
  });
}

/// Swaps the text of one [LinkifiedText] in place, so the widget is updated
/// rather than replaced.
class _SwitchableText extends StatefulWidget {
  const _SwitchableText();

  @override
  State<_SwitchableText> createState() => _SwitchableTextState();
}

class _SwitchableTextState extends State<_SwitchableText> {
  bool _withLink = false;

  @override
  Widget build(BuildContext context) => Column(
    children: <Widget>[
      LinkifiedText(
        _withLink ? 'Jetzt mit https://hs-anhalt.de darin.' : 'Ohne Link.',
      ),
      TextButton(
        onPressed: () => setState(() => _withLink = !_withLink),
        child: const Text('wechseln'),
      ),
    ],
  );
}

String _plainText(WidgetTester tester) {
  final SelectableText widget = tester.widget<SelectableText>(
    find.byType(SelectableText),
  );
  return widget.textSpan?.toPlainText() ?? widget.data ?? '';
}

int _recognizerCount(WidgetTester tester) {
  final SelectableText widget = tester.widget<SelectableText>(
    find.byType(SelectableText),
  );
  final InlineSpan? span = widget.textSpan;
  if (span == null) return 0;
  int count = 0;
  void visit(InlineSpan node) {
    if (node is TextSpan) {
      if (node.recognizer != null) count++;
      node.children?.forEach(visit);
    }
  }

  visit(span);
  return count;
}
