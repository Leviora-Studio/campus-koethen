// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'dart:typed_data';

import 'package:campus_koethen/core/documents/document_viewer_screen.dart';
import 'package:campus_koethen/features/mail/domain/mail_message.dart';
import 'package:campus_koethen/features/mail/presentation/mail_attachment_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import "package:campus_koethen/core/theme/app_icons.dart";

import '../../support/pump_app.dart';

/// A valid 1×1 transparent PNG, so Image.memory decodes without error.
const List<int> _pngBytes = <int>[
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0A,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0x00,
  0x01,
  0x00,
  0x00,
  0x05,
  0x00,
  0x01,
  0x0D,
  0x0A,
  0x2D,
  0xB4,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
];

void main() {
  group('MailAttachmentView', () {
    testWidgets('renders image attachments inline automatically', (
      WidgetTester tester,
    ) async {
      final attachment = MailAttachment(
        filename: 'foto.png',
        mediaType: 'image/png',
        bytes: Uint8List.fromList(_pngBytes),
        sizeBytes: _pngBytes.length,
      );

      await pumpScreen(
        tester,
        Scaffold(body: MailAttachmentView(attachment: attachment)),
      );
      await tester.pumpAndSettle();

      expect(find.text('foto.png'), findsOneWidget);
      expect(find.byType(Image), findsOneWidget);
      expect(find.byIcon(AppIcons.ios_share), findsOneWidget);
    });

    testWidgets('shows understandable placeholder for corrupt image bytes', (
      WidgetTester tester,
    ) async {
      final attachment = MailAttachment(
        filename: 'corrupted.png',
        mediaType: 'image/png',
        bytes: Uint8List.fromList(<int>[1, 2, 3, 4, 5]),
        sizeBytes: 5,
      );

      await pumpScreen(
        tester,
        Scaffold(body: MailAttachmentView(attachment: attachment)),
      );
      await tester.pumpAndSettle();

      expect(find.text('corrupted.png'), findsOneWidget);
      expect(find.byIcon(AppIcons.broken_image_outlined), findsOneWidget);
      expect(
        find.text('Für diesen Anhang ist keine Vorschau möglich.'),
        findsOneWidget,
      );
    });

    testWidgets('shows non-image attachments without inline preview', (
      WidgetTester tester,
    ) async {
      const attachment = MailAttachment(
        filename: 'dokument.pdf',
        mediaType: 'application/pdf',
        sizeBytes: 1024,
      );

      await pumpScreen(
        tester,
        const Scaffold(body: MailAttachmentView(attachment: attachment)),
      );
      await tester.pumpAndSettle();

      expect(find.text('dokument.pdf'), findsOneWidget);
      expect(find.byType(Image), findsNothing);
      expect(find.byIcon(AppIcons.insert_drive_file_outlined), findsOneWidget);
    });

    testWidgets('tapping downloaded attachment opens document viewer', (
      WidgetTester tester,
    ) async {
      final attachment = MailAttachment(
        filename: 'foto.png',
        mediaType: 'image/png',
        bytes: Uint8List.fromList(_pngBytes),
        sizeBytes: _pngBytes.length,
      );

      await pumpScreen(
        tester,
        Scaffold(body: MailAttachmentView(attachment: attachment)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('foto.png'));
      await tester.pumpAndSettle();

      expect(find.byType(DocumentViewerScreen), findsOneWidget);
    });

    testWidgets('a missing download callback shows a retryable failure', (
      WidgetTester tester,
    ) async {
      const attachment = MailAttachment(
        filename: 'nicht_geladen.pdf',
        mediaType: 'application/pdf',
        sizeBytes: 1024,
      );

      await pumpScreen(
        tester,
        const Scaffold(body: MailAttachmentView(attachment: attachment)),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('nicht_geladen.pdf'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Der Anhang konnte nicht geladen werden. Bitte versuche es erneut.',
        ),
        findsOneWidget,
      );
    });
  });
}
