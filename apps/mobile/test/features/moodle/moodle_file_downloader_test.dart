// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer
//
// The Moodle file downloader carries the token, so its host/size/cancel policy
// is security-critical. No real network, no real token.

import 'dart:typed_data';

import 'package:campus_koethen/core/documents/app_document.dart';
import 'package:campus_koethen/features/moodle/data/moodle_file_downloader.dart';
import 'package:campus_koethen/features/moodle/domain/moodle_downloader.dart';
import 'package:campus_koethen/features/moodle/domain/moodle_failure.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../support/fake_bytes_adapter.dart';

const String _moodleFile =
    'https://moodle.hs-anhalt.de/webservice/pluginfile.php/1/mod_resource/content/1/uebung1.pdf';

MoodleFileDownloaderImpl downloaderWith(FakeBytesAdapter adapter) {
  final Dio dio = Dio();
  dio.httpClientAdapter = adapter;
  return MoodleFileDownloaderImpl(dio: dio);
}

Uint8List bytes(int n) => Uint8List.fromList(List<int>.filled(n, 65));

void main() {
  test('downloads a file, attaching the token in the POST body only', () async {
    final FakeBytesAdapter adapter = FakeBytesAdapter(
      (RequestOptions o) =>
          FakeBytes.single(bytes(64), contentType: 'application/pdf'),
    );
    final AppDocument doc = await downloaderWith(adapter).download(
      token: 'tok-secret',
      fileUrl: _moodleFile,
      fileName: 'uebung1.pdf',
      declaredMimeType: 'application/pdf',
    );

    expect(doc.filename, 'uebung1.pdf');
    expect(doc.isPdf, isTrue);
    expect(doc.bytes, hasLength(64));

    final RequestOptions req = adapter.requests.single;
    expect(req.uri.host, 'moodle.hs-anhalt.de');
    // Token must never appear in the URL.
    expect(req.uri.toString(), isNot(contains('tok-secret')));
    expect(req.uri.query, isEmpty);
    final Map<String, dynamic> data = req.data as Map<String, dynamic>;
    expect(data['token'], 'tok-secret');
  });

  test('refuses a non-moodle host and never sends the token', () async {
    final FakeBytesAdapter adapter = FakeBytesAdapter(
      (RequestOptions o) => FakeBytes.single(bytes(8)),
    );
    await expectLater(
      downloaderWith(adapter).download(
        token: 'tok',
        fileUrl: 'https://evil.example.com/file.pdf',
        fileName: 'file.pdf',
      ),
      throwsA(const MoodleFailure(MoodleFailureKind.tlsOrHostRejected)),
    );
    expect(adapter.requests, isEmpty);
  });

  test('refuses a non-https url', () async {
    final FakeBytesAdapter adapter = FakeBytesAdapter(
      (RequestOptions o) => FakeBytes.single(bytes(8)),
    );
    await expectLater(
      downloaderWith(adapter).download(
        token: 'tok',
        fileUrl: 'http://moodle.hs-anhalt.de/file.pdf',
        fileName: 'file.pdf',
      ),
      throwsA(const MoodleFailure(MoodleFailureKind.tlsOrHostRejected)),
    );
    expect(adapter.requests, isEmpty);
  });

  test('refuses a malformed URL without throwing a raw parser error', () async {
    final FakeBytesAdapter adapter = FakeBytesAdapter(
      (RequestOptions o) => FakeBytes.single(bytes(8)),
    );
    await expectLater(
      downloaderWith(adapter).download(
        token: 'tok',
        fileUrl: 'https://[broken/file.pdf',
        fileName: 'file.pdf',
      ),
      throwsA(const MoodleFailure(MoodleFailureKind.tlsOrHostRejected)),
    );
    expect(adapter.requests, isEmpty);
  });

  test(
    'rejects a declared size over the in-memory cap before downloading',
    () async {
      final FakeBytesAdapter adapter = FakeBytesAdapter(
        (RequestOptions o) => FakeBytes.single(bytes(8)),
      );
      await expectLater(
        downloaderWith(adapter).download(
          token: 'tok',
          fileUrl: _moodleFile,
          fileName: 'huge.bin',
          declaredSize: kMaxInMemoryPreviewBytes + 1,
        ),
        throwsA(const MoodleFailure(MoodleFailureKind.fileTooLarge)),
      );
      expect(adapter.requests, isEmpty);
    },
  );

  test('aborts when the stream exceeds the cap, keeping no bytes', () async {
    // Server lies: content-length small, but streams more than the cap.
    final FakeBytesAdapter adapter = FakeBytesAdapter(
      (RequestOptions o) => FakeBytes(<Uint8List>[
        bytes(kMaxInMemoryPreviewBytes ~/ 2),
        bytes(kMaxInMemoryPreviewBytes),
      ], contentLength: 10),
    );
    await expectLater(
      downloaderWith(
        adapter,
      ).download(token: 'tok', fileUrl: _moodleFile, fileName: 'liar.bin'),
      throwsA(const MoodleFailure(MoodleFailureKind.fileTooLarge)),
    );
  });

  test('a redirect is refused and the token is not replayed', () async {
    final FakeBytesAdapter adapter = FakeBytesAdapter(
      (RequestOptions o) => FakeBytes.redirect('https://evil.example.com/x'),
    );
    await expectLater(
      downloaderWith(
        adapter,
      ).download(token: 'tok', fileUrl: _moodleFile, fileName: 'r.bin'),
      throwsA(const MoodleFailure(MoodleFailureKind.tlsOrHostRejected)),
    );
    expect(adapter.requests, hasLength(1));
  });

  test('cancellation discards the download', () async {
    final MoodleDownloadCancel cancel = MoodleDownloadCancel()..cancel();
    final FakeBytesAdapter adapter = FakeBytesAdapter(
      (RequestOptions o) => FakeBytes.single(bytes(64)),
    );
    await expectLater(
      downloaderWith(adapter).download(
        token: 'tok',
        fileUrl: _moodleFile,
        fileName: 'c.bin',
        cancel: cancel,
      ),
      throwsA(const MoodleFailure(MoodleFailureKind.downloadFailed)),
    );
  });
}
