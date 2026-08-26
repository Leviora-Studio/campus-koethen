// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'dart:typed_data';

import 'request_drafts.dart';

/// Port: where a draft's attachments live between picking and sending.
///
/// A draft can hold a **copy of a student card**. Keeping that as a readable
/// file in the app's documents directory — which is what the first version did
/// — leaves an identity document lying around for as long as the draft exists,
/// readable by anything that can reach the app's sandbox. So the bytes are
/// stored encrypted and only ever come back into the process that asked for
/// them.
///
/// [read] returns bytes rather than a path on purpose: no plaintext copy is
/// written to disk at any point, not even briefly, so there is no temporary
/// file that a crash could leave behind. The bytes exist in memory for the
/// duration of one request and are then unreachable.
abstract interface class AttachmentStore {
  /// Stores [bytes] under a new identifier and returns the reference to keep
  /// in the draft.
  Future<RequestAttachment?> put(String fileName, Uint8List bytes);

  /// Returns the decrypted bytes, or `null` when the entry is gone — a draft
  /// can outlive its attachments if storage was cleared.
  Future<Uint8List?> read(RequestAttachment attachment);

  /// Removes one entry. Never touches the user's original file.
  Future<void> delete(RequestAttachment attachment);

  /// Removes several entries. Used once a submission is safely recorded.
  Future<void> deleteAll(Iterable<RequestAttachment> attachments);

  /// Removes the whole store, its key included, and confirms it is gone.
  ///
  /// Also the sweep for orphaned bytes (SET-3): an app killed between `put()`
  /// and the draft save leaves attachment bytes nothing references, and there
  /// was no path that could remove them.
  Future<bool> wipeEverything();
}
