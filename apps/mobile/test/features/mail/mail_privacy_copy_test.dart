// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:campus_koethen/core/locale/locale_mode.dart';
import 'package:campus_koethen/features/legal/presentation/legal_screen.dart';
import 'package:campus_koethen/features/mail/presentation/mail_setup_screen.dart';
import 'package:campus_koethen/l10n/l10n.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/pump_app.dart';

Future<AppLocalizations> _l10n(Locale locale) =>
    AppLocalizations.delegate.load(locale);

void _smallPhone(WidgetTester tester) {
  tester.view.physicalSize = const Size(320, 568);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  test(
    'German and English mail privacy copy describe the same contract',
    () async {
      final AppLocalizations de = await _l10n(AppLocales.german);
      final AppLocalizations en = await _l10n(AppLocales.english);

      for (final String text in <String>[
        de.privacyMailBody,
        '${de.mailSetupIntro} ${de.mailSetupPrivacy}',
      ]) {
        expect(text, contains('TLS'));
        expect(text, contains('Campus-API'));
        expect(text, contains('sicheren Schlüsselspeicher'));
        expect(text, contains('E-Mail-Kopfzeilen'));
        expect(text, contains('Nachrichteninhalte'));
        expect(text, contains('Adressen'));
        expect(text, contains('Anhänge'));
        expect(text, contains('verschlüsselten Cache'));
        expect(text, contains('Verschlüsselungsschlüssel'));
        expect(text, contains('Hochschulserver bleiben unverändert'));
        expect(text, isNot(contains('speichert keine E-Mails dauerhaft')));
      }

      for (final String text in <String>[
        en.privacyMailBody,
        '${en.mailSetupIntro} ${en.mailSetupPrivacy}',
      ]) {
        expect(text, contains('TLS'));
        expect(text, contains('Campus API'));
        expect(text, contains('secure keystore'));
        expect(text, contains('email headers'));
        expect(text, contains('message contents'));
        expect(text, contains('addresses'));
        expect(text, contains('attachments'));
        expect(text, contains('encrypted cache'));
        expect(text, contains('encryption key'));
        expect(text, contains('university server remains unchanged'));
        expect(text, isNot(contains('does not store any emails permanently')));
      }

      expect(
        de.mailAccountRemoveConfirmBody,
        contains('offline gespeicherte Maildaten'),
      );
      expect(
        de.mailAccountRemoveConfirmBody,
        contains('Verschlüsselungsschlüssel'),
      );
      expect(
        de.mailAccountRemoveConfirmBody,
        contains('Hochschulserver bleiben unverändert'),
      );
      expect(en.mailAccountRemoveConfirmBody, contains('offline mail data'));
      expect(en.mailAccountRemoveConfirmBody, contains('encryption key'));
      expect(
        en.mailAccountRemoveConfirmBody,
        contains('university server remains unchanged'),
      );
    },
  );

  testWidgets(
    'mail setup remains fully reachable on a small phone with large text',
    (WidgetTester tester) async {
      _smallPhone(tester);
      await pumpScreen(
        tester,
        const MailSetupScreen(),
        textScaler: const TextScaler.linear(2),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      await tester.scrollUntilVisible(
        find.text('Webmail im Browser öffnen'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Webmail im Browser öffnen'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'the privacy page remains fully reachable in English with large text',
    (WidgetTester tester) async {
      _smallPhone(tester);
      await pumpScreen(
        tester,
        const LegalScreen(page: LegalPage.privacy),
        locale: AppLocales.english,
        textScaler: const TextScaler.linear(2),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      // The independence notice closes the page. That page grew from a short
      // placeholder into fifteen sections of real privacy text, so at a
      // doubled text size on a small phone it is roughly 48,000 px tall in a
      // 469 px viewport.
      //
      // Driven through the scroll position rather than with
      // `scrollUntilVisible`, for two reasons the old call fell over on:
      // the screen nests a second Scrollable that swallows a synthesised drag
      // aimed at the centre of the outer one, and 50 drags of 300 px covered
      // less than a third of the page anyway. Stepping by viewport stops as
      // soon as the heading is built, rather than at the very bottom — where
      // only the notice's body is on screen and its title is already above
      // the fold.
      final ScrollPosition position = tester
          .state<ScrollableState>(find.byType(Scrollable).first)
          .position;
      final Finder notice = find.text('Independence notice');
      double offset = 0;
      while (notice.evaluate().isEmpty && offset < position.maxScrollExtent) {
        offset = (offset + position.viewportDimension * 0.8).clamp(
          0,
          position.maxScrollExtent,
        );
        position.jumpTo(offset);
        await tester.pumpAndSettle();
      }
      expect(find.text('Independence notice'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
