// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/prefs/settings_controller.dart';
import '../domain/mail_credentials.dart';
import '../domain/mail_folder.dart';
import '../domain/mail_failure.dart';
import '../domain/mail_message.dart';
import 'mail_account_controller.dart';
import 'mail_folders.dart';
import 'mail_providers.dart';
import 'mail_sync_controller.dart';

const int kInboxLimit = 50;

/// Provides the message list of the currently selected mailbox.
///
/// The INBOX is served from the offline cache, so it appears instantly and
/// works offline; a background sync (see [MailSyncController]) keeps it fresh
/// and the list rebuilds via [mailCacheRevisionProvider]. Other folders are
/// fetched online on demand — they are not cached.
class MailInboxController extends AsyncNotifier<List<MailMessageHeader>> {
  @override
  Future<List<MailMessageHeader>> build() async {
    final account = ref.watch(mailAccountControllerProvider).value;
    if (account == null || !account.isSignedIn) {
      return const <MailMessageHeader>[];
    }
    final MailFolder folder = ref.watch(selectedMailboxProvider);

    if (folder.isInbox) {
      // Rebuild whenever the cache changes; read from the cache (offline-first).
      ref.watch(mailCacheRevisionProvider);
      return ref.read(mailCacheStoreProvider).readHeaders();
    }

    // Other folders: online, uncached.
    final credentials = await ref
        .read(mailAccountControllerProvider.notifier)
        .requireCredentials();
    return ref
        .read(mailGatewayProvider)
        .fetchHeaders(
          credentials,
          mailboxPath: folder.path,
          limit: kInboxLimit,
        );
  }

  /// Manual refresh. For the INBOX this triggers a background sync (which
  /// updates the cache and, in turn, this list); for other folders it re-fetches.
  Future<void> refresh() async {
    final MailFolder folder = ref.read(selectedMailboxProvider);
    if (folder.isInbox) {
      await ref.read(mailSyncControllerProvider.notifier).syncNow();
      return;
    }
    state = const AsyncLoading<List<MailMessageHeader>>();
    state = await AsyncValue.guard(() async {
      final credentials = await ref
          .read(mailAccountControllerProvider.notifier)
          .requireCredentials();
      return ref
          .read(mailGatewayProvider)
          .fetchHeaders(
            credentials,
            mailboxPath: folder.path,
            limit: kInboxLimit,
          );
    });
  }

  /// Downloads the complete message again so attachment bytes that were left
  /// out of the offline prefetch become available after an explicit tap.
  ///
  /// For the INBOX the enriched detail replaces the metadata-only cache entry;
  /// other folders keep their existing online-only behaviour.
  Future<MailMessageDetail> downloadAttachments(MailMessageRef message) async {
    final MailCredentials credentials = await ref
        .read(mailAccountControllerProvider.notifier)
        .requireCredentials();
    final MailAccountController accountController = ref.read(
      mailAccountControllerProvider.notifier,
    );
    final int generation = accountController.sessionGeneration;
    final MailMessageDetail detail = await ref
        .read(mailGatewayProvider)
        .fetchMessage(
          credentials,
          mailboxPath: message.mailboxPath,
          id: message.id,
          includeAttachmentBytes: true,
        );
    if (!accountController.isSessionCurrent(generation)) {
      throw const MailFailure(MailFailureKind.sessionClosed);
    }
    if (message.mailboxPath == kInboxPath) {
      await ref.read(mailCacheStoreProvider).saveMessage(detail);
      if (!accountController.isSessionCurrent(generation)) {
        throw const MailFailure(MailFailureKind.sessionClosed);
      }
      ref.read(mailCacheRevisionProvider.notifier).bump();
    }
    return detail;
  }
}

final AsyncNotifierProvider<MailInboxController, List<MailMessageHeader>>
mailInboxControllerProvider =
    AsyncNotifierProvider<MailInboxController, List<MailMessageHeader>>(
      MailInboxController.new,
      // No silent auto-retry: a failed fetch (timeout, TLS, auth) must surface
      // to the user as an error they can retry, not spin in exponential backoff.
      retry: (_, _) => null,
    );

/// Identifies one message: its mailbox path and its per-mailbox id (UID).
typedef MailMessageRef = ({String mailboxPath, String id});

/// One message detail. For the INBOX the cache is consulted first (instant,
/// offline); a cache miss falls back to the network and the result is cached.
/// Marks the message \Seen on the server after a successful load.
final mailMessageProvider =
    FutureProvider.family<MailMessageDetail, MailMessageRef>((
      Ref ref,
      MailMessageRef message,
    ) async {
      ref.watch(mailSessionGenerationProvider);
      final bool isInbox = message.mailboxPath == kInboxPath;
      final cache = ref.read(mailCacheStoreProvider);

      if (isInbox) {
        final MailMessageDetail? cached = await cache.readMessage(message.id);
        if (cached != null) {
          await _markSeenLocally(ref, message);
          // Best effort: mark seen on the server without blocking the read.
          unawaited(_markSeen(ref, message));
          return cached;
        }
      }

      final credentials = await ref
          .read(mailAccountControllerProvider.notifier)
          .requireCredentials();
      final MailAccountController accountController = ref.read(
        mailAccountControllerProvider.notifier,
      );
      final int generation = accountController.sessionGeneration;
      final gateway = ref.read(mailGatewayProvider);
      final bool downloadAttachments = ref
          .read(settingsProvider)
          .mailDownloadAttachments;
      final detail = await gateway.fetchMessage(
        credentials,
        mailboxPath: message.mailboxPath,
        id: message.id,
        includeAttachmentBytes: downloadAttachments,
      );
      if (!accountController.isSessionCurrent(generation)) {
        throw const MailFailure(MailFailureKind.sessionClosed);
      }
      if (isInbox) {
        await cache.saveMessage(detail);
        if (!accountController.isSessionCurrent(generation)) {
          throw const MailFailure(MailFailureKind.sessionClosed);
        }
        ref.read(mailCacheRevisionProvider.notifier).bump();
        await _markSeenLocally(ref, message);
      }
      unawaited(_markSeen(ref, message));
      return detail;
    }, retry: (_, _) => null);

/// Flips the cached header's \Seen flag and rebuilds the inbox, so the list
/// reflects "read" immediately after opening — no sync required. A no-op when
/// the header isn't cached (nothing to show yet) or is already marked seen.
Future<void> _markSeenLocally(Ref ref, MailMessageRef message) async {
  final cache = ref.read(mailCacheStoreProvider);
  final List<MailMessageHeader> headers = await cache.readHeaders();
  final int index = headers.indexWhere(
    (MailMessageHeader h) => h.id == message.id,
  );
  if (index == -1 || headers[index].isSeen) return;
  final List<MailMessageHeader> updated = List<MailMessageHeader>.of(headers);
  updated[index] = updated[index].copyWith(isSeen: true);
  await cache.saveHeaders(updated);
  ref.read(mailCacheRevisionProvider.notifier).bump();
}

/// Best-effort server sync of the \Seen flag. Never throws: a network failure
/// here must not affect the (already successful) local open — a later header
/// sync reconciles with the confirmed server state.
Future<void> _markSeen(Ref ref, MailMessageRef message) async {
  try {
    final credentials = await ref
        .read(mailAccountControllerProvider.notifier)
        .requireCredentials();
    await ref
        .read(mailGatewayProvider)
        .markSeen(
          credentials,
          mailboxPath: message.mailboxPath,
          id: message.id,
        );
  } catch (_) {}
}
