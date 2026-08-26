// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import '../../../core/cache/encrypted_box.dart';
import '../domain/attachment_store.dart';
import '../domain/request_drafts.dart';

/// Keeps draft attachments encrypted at rest.
///
/// The first version copied picked files into the app's documents directory as
/// plaintext. For a grocery list that would be fine; for a **student card** it
/// is not — the copy sits there for as long as the draft does, readable by
/// anything with access to the app's sandbox, and survives until someone
/// remembers to clean it up.
///
/// Here the bytes are base64-encoded into the app's encrypted box, whose AES
/// key lives only in the keychain/keystore. They come back into memory when a
/// submission needs them and are written to disk in the clear at no point —
/// so there is no temporary plaintext file for a crash to leave behind, and
/// nothing to forget to delete in a `finally`.
///
/// The user's **original file is never touched**: this store only ever owns
/// its own copy.
class EncryptedAttachmentStore implements AttachmentStore {
  EncryptedAttachmentStore({EncryptedBox? box, Random? random})
    : _box =
          box ??
          EncryptedBox(
            boxName: 'campus_request_files_v1',
            keyStorageKey: 'campus_request_files_key_v1',
          ),
      _random = random ?? Random.secure();

  static const String _prefix = 'attachment:';

  @override
  Future<bool> wipeEverything() async {
    final EncryptedBoxWipeResult wiped = await _box.wipeChecked();
    return wiped.isComplete;
  }

  final EncryptedBox _box;
  final Random _random;

  @override
  Future<RequestAttachment?> put(String fileName, Uint8List bytes) async {
    final String id = '$_prefix${_token()}';
    await _box.write(id, base64Encode(bytes));
    // Read back: a draft that references bytes the store never kept would fail
    // at submission time, long after the user could still fix it.
    if (await _box.read(id) == null) return null;
    return RequestAttachment(
      fileName: fileName,
      path: id,
      sizeBytes: bytes.length,
    );
  }

  @override
  Future<Uint8List?> read(RequestAttachment attachment) async {
    final String? raw = await _box.read(attachment.path);
    if (raw == null) return null;
    try {
      return base64Decode(raw);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> delete(RequestAttachment attachment) =>
      _box.delete(attachment.path);

  @override
  Future<void> deleteAll(Iterable<RequestAttachment> attachments) async {
    for (final RequestAttachment attachment in attachments) {
      await delete(attachment);
    }
  }

  String _token() {
    final List<int> bytes = List<int>.generate(
      16,
      (_) => _random.nextInt(256),
      growable: false,
    );
    return bytes.map((int b) => b.toRadixString(16).padLeft(2, '0')).join();
  }
}
