// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'dart:typed_data';

import 'package:dio/dio.dart';

import '../../../core/documents/app_document.dart';
import '../domain/moodle_downloader.dart';
import '../domain/moodle_failure.dart';
import '../domain/moodle_profile.dart';

/// Downloads a single Moodle file on demand into memory.
///
/// Security policy, all central and non-bypassable:
///  * the file URL must be HTTPS on `moodle.hs-anhalt.de` — otherwise the
///    request is refused and the token is never sent;
///  * the token travels in the POST body, never in the URL;
///  * redirects are never followed with the token;
///  * a declared size or an actual stream exceeding [kMaxInMemoryPreviewBytes]
///    aborts with [MoodleFailureKind.fileTooLarge];
///  * a cancelled or failed transfer keeps no partial bytes (the buffer is
///    local and simply discarded — nothing is written to disk).
class MoodleFileDownloaderImpl implements MoodleFileDownloader {
  MoodleFileDownloaderImpl({
    Dio? dio,
    this.profile = const MoodleProfile(),
    this.maxBytes = kMaxInMemoryPreviewBytes,
  }) : _dio = dio ?? Dio();

  final Dio _dio;
  final MoodleProfile profile;
  final int maxBytes;

  @override
  Future<AppDocument> download({
    required String token,
    required String fileUrl,
    required String fileName,
    String? declaredMimeType,
    int? declaredSize,
    MoodleDownloadProgress? onProgress,
    MoodleDownloadCancel? cancel,
  }) async {
    final Uri? uri = Uri.tryParse(fileUrl);
    if (uri == null || !profile.allows(uri)) {
      // Wrong scheme or host: never attach the token, never send.
      throw const MoodleFailure(MoodleFailureKind.tlsOrHostRejected);
    }
    if (declaredSize != null && declaredSize > maxBytes) {
      throw const MoodleFailure(MoodleFailureKind.fileTooLarge);
    }
    if (cancel?.isCancelled ?? false) {
      throw const MoodleFailure(MoodleFailureKind.downloadFailed);
    }

    late final Response<ResponseBody> response;
    try {
      response = await _dio.postUri<ResponseBody>(
        uri,
        data: <String, String>{'token': token},
        options: Options(
          contentType: Headers.formUrlEncodedContentType,
          responseType: ResponseType.stream,
          followRedirects: false,
          validateStatus: (_) => true,
        ),
      );
    } on DioException {
      throw const MoodleFailure(MoodleFailureKind.downloadFailed);
    }

    final int status = response.statusCode ?? 0;
    if (status >= 300 && status < 400) {
      throw const MoodleFailure(MoodleFailureKind.tlsOrHostRejected);
    }
    if (status < 200 || status >= 300) {
      throw const MoodleFailure(MoodleFailureKind.downloadFailed);
    }

    final int? contentLength = int.tryParse(
      response.headers.value(Headers.contentLengthHeader) ?? '',
    );
    if (contentLength != null && contentLength > maxBytes) {
      throw const MoodleFailure(MoodleFailureKind.fileTooLarge);
    }

    final ResponseBody? body = response.data;
    if (body == null) {
      throw const MoodleFailure(MoodleFailureKind.downloadFailed);
    }

    final BytesBuilder builder = BytesBuilder(copy: false);
    try {
      await for (final Uint8List chunk in body.stream) {
        if (cancel?.isCancelled ?? false) {
          throw const MoodleFailure(MoodleFailureKind.downloadFailed);
        }
        builder.add(chunk);
        if (builder.length > maxBytes) {
          throw const MoodleFailure(MoodleFailureKind.fileTooLarge);
        }
        if (contentLength != null && contentLength > 0) {
          onProgress?.call(builder.length / contentLength);
        } else {
          onProgress?.call(null);
        }
      }
    } on MoodleFailure {
      rethrow;
    } catch (_) {
      // Any transport error mid-stream: discard the partial buffer.
      throw const MoodleFailure(MoodleFailureKind.downloadFailed);
    }

    final Uint8List data = builder.takeBytes();
    return AppDocument(
      filename: fileName,
      mediaType: mediaTypeFor(fileName, declared: declaredMimeType),
      bytes: data,
      sizeBytes: data.length,
    );
  }
}
