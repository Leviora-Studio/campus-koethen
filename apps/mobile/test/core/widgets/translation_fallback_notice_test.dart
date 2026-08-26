// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:campus_koethen/core/locale/locale_mode.dart';
import 'package:campus_koethen/core/theme/app_icons.dart';
import 'package:campus_koethen/core/widgets/translation_fallback_notice.dart';
import 'package:campus_koethen/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Future<void> _pump(WidgetTester tester, Locale locale) => tester.pumpWidget(
  MaterialApp(
    locale: locale,
    supportedLocales: AppLocales.supported,
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    home: const Scaffold(body: TranslationFallbackNotice()),
  ),
);

void main() {
  testWidgets('explains a German content fallback in English', (
    WidgetTester tester,
  ) async {
    await _pump(tester, AppLocales.english);

    expect(find.byIcon(AppIcons.translate_outlined), findsOneWidget);
    expect(
      find.text(
        'Some content is not available in English yet. '
        'The original German text is shown.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('has a German localisation as well', (WidgetTester tester) async {
    await _pump(tester, AppLocales.german);

    expect(find.textContaining('deutsche Originaltext'), findsOneWidget);
  });
}
