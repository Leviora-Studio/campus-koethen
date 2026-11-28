// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'dart:typed_data';

String? mailImageContentId(String? source) {
  if (source == null || !source.toLowerCase().startsWith('cid:')) return null;
  try {
    final id = Uri.decodeComponent(source.substring(4)).trim().toLowerCase();
    return id.isEmpty ? null : id;
  } on FormatException {
    return null;
  } on ArgumentError {
    return null;
  }
}

bool isSupportedMailImage(String? type) => const {
  'image/png',
  'image/jpeg',
  'image/gif',
  'image/webp',
}.contains(type?.toLowerCase());

Uint8List? decodeMailDataImage(String source) {
  if (!source.startsWith('data:') || source.length > 2 * 1024 * 1024) {
    return null;
  }
  try {
    final data = UriData.parse(source);
    if (!data.isBase64 || !isSupportedMailImage(data.mimeType)) return null;
    return data.contentAsBytes();
  } on FormatException {
    return null;
  }
}
