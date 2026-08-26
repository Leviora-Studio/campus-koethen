// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:campus_koethen/core/documents/app_document.dart';
import 'package:flutter_test/flutter_test.dart';

/// What may become a filename on disk.
///
/// Sharing a document writes its bytes to a file named after the document, and
/// every one of those names arrived over the network: a mail attachment's MIME
/// name, a Moodle file name, the `filename` of a case document. `share_plus`
/// joins the name onto its temporary directory without inspecting it, so a name
/// that contains a separator or a `..` writes somewhere else entirely.
void main() {
  group('safeDocumentFilename', () => _filenameTests());
}

void _filenameTests() {
  test('leaves an ordinary attachment name alone', () {
    expect(safeDocumentFilename('Antrag_2026.pdf'), 'Antrag_2026.pdf');
    expect(
      safeDocumentFilename('Übung 3 – Lösung.docx'),
      'Übung 3 – Lösung.docx',
    );
  });

  // The whole point: none of these may keep a separator or a traversal step.
  test('reduces a traversal to its last, harmless segment', () {
    expect(
      safeDocumentFilename('../../shared_prefs/FlutterSharedPreferences.xml'),
      'FlutterSharedPreferences.xml',
    );
    expect(safeDocumentFilename('/etc/passwd'), 'passwd');
    expect(safeDocumentFilename(r'..\..\databases\grades.hive'), 'grades.hive');
    expect(safeDocumentFilename('a/b/c/report.pdf'), 'report.pdf');
  });

  test('never returns a name that is only dots', () {
    for (final String name in <String>['..', '.', '...', '../', '../..']) {
      expect(safeDocumentFilename(name), kFallbackDocumentFilename);
    }
  });

  test('strips control characters and reserved characters', () {
    expect(safeDocumentFilename('re\x00port.pdf'), 'report.pdf');
    expect(safeDocumentFilename('re\r\nport.pdf'), 'report.pdf');
    expect(safeDocumentFilename('re<>:"|?*port.pdf'), 'report.pdf');
  });

  test('falls back when nothing usable is left', () {
    expect(safeDocumentFilename(''), kFallbackDocumentFilename);
    expect(safeDocumentFilename('   '), kFallbackDocumentFilename);
    expect(safeDocumentFilename('\x00\x01'), kFallbackDocumentFilename);
  });

  test('does not produce a hidden file', () {
    expect(safeDocumentFilename('.bashrc'), 'bashrc');
    expect(safeDocumentFilename('../.env'), 'env');
  });

  test('bounds the length while keeping the extension', () {
    final String long = '${'a' * 400}.pdf';
    final String result = safeDocumentFilename(long);
    expect(result.length, lessThanOrEqualTo(120));
    expect(result.endsWith('.pdf'), isTrue);
  });

  // A cut can land in the middle of a run of dots; the result still has to be a
  // plain name rather than something that looks like a traversal step.
  test('a truncated name still starts with a visible character', () {
    final String result = safeDocumentFilename('${'.' * 400}report.pdf');
    expect(result.startsWith('.'), isFalse);
    expect(result, 'report.pdf');
  });
}
