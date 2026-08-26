// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'dart:typed_data';

import 'package:intl/intl.dart';
import 'package:meta/meta.dart';

/// A downloaded document to preview in-app — source-agnostic. Mail attachments
/// and Moodle files both map onto this, so the viewer depends on neither.
@immutable
class AppDocument {
  const AppDocument({
    required this.filename,
    required this.mediaType,
    required this.bytes,
    this.sizeBytes,
  });

  final String filename;
  final String mediaType;
  final Uint8List bytes;
  final int? sizeBytes;

  bool get isImage => documentIsImage(mediaType);
  bool get isPdf => documentIsPdf(mediaType, filename);
  bool get isText => documentIsText(mediaType);
}

/// The largest file the app will hold fully in memory for an in-app preview.
/// Larger files are offered as share/open-externally instead.
const int kMaxInMemoryPreviewBytes = 25 * 1024 * 1024;

bool documentIsImage(String mediaType) =>
    mediaType.toLowerCase().startsWith('image/');

bool documentIsPdf(String mediaType, String filename) =>
    mediaType.toLowerCase() == 'application/pdf' ||
    filename.toLowerCase().endsWith('.pdf');

bool documentIsText(String mediaType) =>
    mediaType.toLowerCase().startsWith('text/');

/// Fallback name for a document whose own name cannot be used as a filename.
const String kFallbackDocumentFilename = 'dokument';

/// The name a document may be written to disk under.
///
/// Every [AppDocument.filename] in this app came off the network: a mail
/// attachment's MIME name, a Moodle file name, the `filename` field of a case
/// document's JSON. None of them is a filename until it has been checked.
///
/// It matters because sharing writes the bytes to a file. `share_plus` joins
/// the name onto its temporary directory (`"$tempSubfolderPath/$filename"`) and
/// writes there without inspecting it, so a name containing `..` or a separator
/// escapes that directory and lands somewhere else the app can write — its own
/// preferences or one of its encrypted boxes, for instance. The app never
/// executes what it writes, so this is an integrity problem rather than a code
/// execution one, but it is one that a remote party gets to choose.
///
/// So the name is reduced to a single, harmless path segment: the last
/// component, with separators, `..`, control characters and the platform's
/// reserved characters removed. A name that has nothing usable left becomes
/// [kFallbackDocumentFilename] — the extension is preserved where it survives,
/// because it is what decides which app opens the file.
String safeDocumentFilename(String filename) {
  // Both separators, so a Windows-style name cannot survive on a POSIX host.
  final String lastSegment = filename.split(_pathSeparators).last;

  final String cleaned = lastSegment
      // Control characters, NUL included, and the characters Windows and
      // several share targets refuse in a filename.
      .replaceAll(_reservedCharacters, '')
      .trim();

  // A name made only of dots is `.`, `..` or a longer traversal-flavoured
  // variant; none of them names a file.
  if (cleaned.isEmpty || _onlyDots.hasMatch(cleaned)) {
    return kFallbackDocumentFilename;
  }

  // Long names are rejected by some filesystems outright; 120 characters is far
  // above any real attachment name and safely below every limit. The TAIL is
  // kept, because that is where the extension lives and the extension is what
  // decides which app opens the file.
  final String bounded = cleaned.length <= 120
      ? cleaned
      : cleaned.substring(cleaned.length - 120);

  // A leading dot makes a hidden file and, more importantly, is what is left of
  // a name like `../config` once the separators are gone. Stripped after the
  // truncation, so a cut cannot put one back.
  final String visible = bounded.replaceFirst(_leadingDots, '');
  return visible.isEmpty ? kFallbackDocumentFilename : visible;
}

/// A compact human-readable size label (`12 KB`, `1,3 MB`).
///
/// [locale] decides the decimal separator. Without it every German screen
/// showed "1.3 MB" with a US point — the one number in the app that ignored
/// the locale, next to prices and dates that all honour it.
String humanFileSize(int bytes, {String? locale}) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) {
    return '${NumberFormat('#,##0', locale).format(bytes / 1024)} KB';
  }
  return '${NumberFormat('#,##0.0', locale).format(bytes / (1024 * 1024))} MB';
}

const Map<String, String> _extensionTypes = <String, String>{
  'pdf': 'application/pdf',
  'png': 'image/png',
  'jpg': 'image/jpeg',
  'jpeg': 'image/jpeg',
  'gif': 'image/gif',
  'webp': 'image/webp',
  'bmp': 'image/bmp',
  'svg': 'image/svg+xml',
  'txt': 'text/plain',
  'md': 'text/markdown',
  'csv': 'text/csv',
  'html': 'text/html',
  'htm': 'text/html',
  'doc': 'application/msword',
  'docx':
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  'ppt': 'application/vnd.ms-powerpoint',
  'pptx':
      'application/vnd.openxmlformats-officedocument.presentationml.presentation',
  'xls': 'application/vnd.ms-excel',
  'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
  'zip': 'application/zip',
};

/// The MIME type for a file: the [declared] type if usable, else guessed from
/// the filename extension, else a safe generic binary type.
String mediaTypeFor(String filename, {String? declared}) {
  final String d = (declared ?? '').trim();
  if (d.isNotEmpty && d != 'application/octet-stream' && d.contains('/')) {
    return d;
  }
  final int dot = filename.lastIndexOf('.');
  if (dot >= 0 && dot < filename.length - 1) {
    final String ext = filename.substring(dot + 1).toLowerCase();
    final String? type = _extensionTypes[ext];
    if (type != null) return type;
  }
  return d.isNotEmpty ? d : 'application/octet-stream';
}

// The four patterns of `safeDocumentFilename`, parsed once rather than on every
// name it is asked about — a mail with a dozen attachments asks it a dozen
// times, and every download and every share asks it again.

/// Both separators, so a Windows-style name cannot survive on a POSIX host.
final RegExp _pathSeparators = RegExp(r'[/\\]');

/// Control characters, NUL included, and the characters Windows and several
/// share targets refuse in a filename.
final RegExp _reservedCharacters = RegExp(r'[\x00-\x1f\x7f<>:"|?*]');

/// A name made only of dots — `.`, `..` or a longer traversal-flavoured
/// variant.
final RegExp _onlyDots = RegExp(r'^\.+$');

final RegExp _leadingDots = RegExp(r'^\.+');
