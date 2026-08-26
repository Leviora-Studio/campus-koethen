// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:share_plus/share_plus.dart';

import 'app_document.dart';

/// Shares a downloaded document through the OS share sheet. The in-memory bytes
/// are written to a temporary file by share_plus with the correct name.
///
/// The name is sanitised first. `share_plus` builds the path it writes to by
/// joining the override straight onto its temporary directory, and the name of
/// a mail attachment, a Moodle file or a case document is chosen by whoever
/// sent it — a `..` in there would put the bytes outside that directory
/// (`safeDocumentFilename`).
class DocumentShareService {
  const DocumentShareService();

  Future<void> share(AppDocument document) async {
    await SharePlus.instance.share(
      ShareParams(
        files: <XFile>[
          XFile.fromData(document.bytes, mimeType: document.mediaType),
        ],
        fileNameOverrides: <String>[safeDocumentFilename(document.filename)],
      ),
    );
  }
}
