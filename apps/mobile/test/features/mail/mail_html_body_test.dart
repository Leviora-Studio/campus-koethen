import 'dart:convert';

import 'package:campus_koethen/features/mail/domain/mail_message.dart';
import 'package:campus_koethen/features/mail/presentation/mail_html_body.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/pump_app.dart';

void main() {
  testWidgets('shows an embedded banner and signature link in the mail body', (
    tester,
  ) async {
    final image = base64Decode(
      'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+X2xUAAAAASUVORK5CYII=',
    );
    await pumpScreen(
      tester,
      Scaffold(
        body: MailHtmlBody(
          detail: MailMessageDetail(
            id: 'demo',
            subject: 'Demo',
            from: const MailAddress(email: 'demo@example.test'),
            to: const [],
            date: null,
            body: '',
            html: '''
            <img src="cid:demo%40example.test" alt="Demo banner">
            <p>Demo message</p>
            <p><a href="https://example.test">Demo signature</a></p>
            <img src="https://example.test/remote.png" alt="Remote graphic">
            <script>Ignore me</script>
          ''',
            inlineImages: {'demo@example.test': image},
          ),
        ),
      ),
    );
    expect(find.byType(Image), findsOneWidget);
    expect(tester.widget<Image>(find.byType(Image)).image, isA<MemoryImage>());
    expect(
      find.textContaining('Demo message', findRichText: true),
      findsOneWidget,
    );
    expect(
      find.textContaining('Demo signature', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('Remote graphic'), findsOneWidget);
    expect(find.textContaining('Ignore me', findRichText: true), findsNothing);
  });
}
