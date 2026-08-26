// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'dart:typed_data';

import 'package:flutter/material.dart';
import "package:campus_koethen/core/theme/app_icons.dart";

import '../../../core/documents/app_document.dart';
import '../../../core/documents/document_share_service.dart';
import '../../../core/documents/document_viewer_screen.dart';
import '../../../core/theme/app_dimensions.dart';
import '../../../l10n/l10n.dart';
import '../domain/mail_message.dart';

const DocumentShareService _shareService = DocumentShareService();

AppDocument _asDocument(MailAttachment a) => AppDocument(
  filename: a.filename,
  mediaType: a.mediaType,
  bytes: a.bytes!,
  sizeBytes: a.sizeBytes,
);

/// One attachment in the message detail.
///
/// Downloaded image attachments preview inline automatically; tapping any
/// downloaded attachment opens it in the shared [DocumentViewerScreen].
class MailAttachmentView extends StatelessWidget {
  const MailAttachmentView({required this.attachment, super.key});

  final MailAttachment attachment;

  void _open(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    if (attachment.bytes == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.mailAttachmentNotDownloaded)));
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext _) =>
            DocumentViewerScreen(document: _asDocument(attachment)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final TextTheme text = Theme.of(context).textTheme;
    final int? size = attachment.sizeBytes;
    final String subtitle = <String>[
      attachment.mediaType,
      if (size != null)
        humanFileSize(
          size,
          locale: Localizations.localeOf(context).languageCode,
        ),
    ].join(' · ');

    final Widget tile = ListTile(
      leading: Icon(
        attachment.isImage
            ? AppIcons.image_outlined
            : AppIcons.insert_drive_file_outlined,
      ),
      title: Text(
        attachment.filename,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(subtitle, style: text.bodySmall),
      onTap: () => _open(context),
      trailing: attachment.bytes == null
          ? null
          : IconButton(
              onPressed: () => _shareService.share(_asDocument(attachment)),
              tooltip: l10n.mailAttachmentShare,
              icon: const Icon(AppIcons.ios_share),
            ),
    );

    final Uint8List? imageBytes = attachment.isImage ? attachment.bytes : null;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          if (imageBytes != null)
            // The preview opens the same attachment as the tile below it. Left
            // in the tree it was a second, unlabelled tap target announcing
            // only "image" — so it is excluded and the tile stays the one way
            // in.
            ExcludeSemantics(
              child: InkWell(
                onTap: () => _open(context),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 320),
                  child: Image.memory(
                    imageBytes,
                    fit: BoxFit.contain,
                    errorBuilder:
                        (
                          BuildContext context,
                          Object error,
                          StackTrace? stackTrace,
                        ) => const _ImageErrorPlaceholder(),
                  ),
                ),
              ),
            ),
          tile,
        ],
      ),
    );
  }
}

class _ImageErrorPlaceholder extends StatelessWidget {
  const _ImageErrorPlaceholder();

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ColorScheme colors = Theme.of(context).colorScheme;
    final TextTheme text = Theme.of(context).textTheme;

    return ColoredBox(
      color: colors.surfaceContainerHighest.withValues(alpha: 0.5),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppSpacing.lg,
          horizontal: AppSpacing.md,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Icon(
              AppIcons.broken_image_outlined,
              size: AppSizes.icon,
              color: colors.onSurfaceVariant,
            ),
            const SizedBox(width: AppSpacing.sm),
            Flexible(
              child: Text(
                l10n.mailAttachmentPreviewUnavailable,
                style: text.bodySmall?.copyWith(color: colors.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
