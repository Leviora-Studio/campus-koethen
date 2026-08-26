// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';

/// A scripted [HttpClientAdapter] that streams raw bytes, for testing the
/// Moodle file downloader without any real network.
class FakeBytesAdapter implements HttpClientAdapter {
  FakeBytesAdapter(this.responder);

  final FutureOr<FakeBytes> Function(RequestOptions options) responder;
  final List<RequestOptions> requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final FakeBytes r = await responder(options);
    final Map<String, List<String>> headers = <String, List<String>>{
      Headers.contentTypeHeader: <String>[r.contentType],
      if (r.contentLength != null)
        Headers.contentLengthHeader: <String>['${r.contentLength}'],
      if (r.location != null) 'location': <String>[r.location!],
    };
    Stream<Uint8List> streamChunks() async* {
      for (final (int index, Uint8List chunk) in r.chunks.indexed) {
        r.onChunkRead?.call(index);
        yield chunk;
        // Model an actual socket: cancellation after one chunk must be observed
        // before the producer offers the next one.
        await Future<void>.delayed(Duration.zero);
      }
    }

    return ResponseBody(streamChunks(), r.statusCode, headers: headers);
  }

  @override
  void close({bool force = false}) {}
}

class FakeBytes {
  FakeBytes(
    this.chunks, {
    this.statusCode = 200,
    this.contentType = 'application/octet-stream',
    this.contentLength,
    this.location,
    this.onChunkRead,
  });

  FakeBytes.single(
    Uint8List bytes, {
    int statusCode = 200,
    String contentType = 'application/octet-stream',
    int? contentLength,
  }) : this(
         <Uint8List>[bytes],
         statusCode: statusCode,
         contentType: contentType,
         contentLength: contentLength ?? bytes.length,
       );

  FakeBytes.redirect(this.location)
    : chunks = <Uint8List>[Uint8List(0)],
      statusCode = 302,
      contentType = 'text/html',
      contentLength = null,
      onChunkRead = null;

  final List<Uint8List> chunks;
  final int statusCode;
  final String contentType;
  final int? contentLength;
  final String? location;
  final void Function(int index)? onChunkRead;
}
