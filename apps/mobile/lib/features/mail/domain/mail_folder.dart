// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:meta/meta.dart';

/// The canonical IMAP path of the inbox. Selecting it needs no server lookup.
const String kInboxPath = 'INBOX';

/// Special-use role of a mailbox, derived from its IMAP flags. Used to show a
/// meaningful icon and a localized label instead of the raw server name.
enum MailFolderRole { inbox, sent, drafts, trash, junk, archive, plain }

/// A mailbox as shown in the folder list.
///
/// [path] is the IMAP path used to re-select the mailbox; [name] is what the
/// user sees. The two differ for nested or specially encoded folders.
@immutable
class MailFolder {
  const MailFolder({
    required this.path,
    required this.name,
    this.role = MailFolderRole.plain,
    this.isSelectable = true,
  });

  /// The inbox, available without a server round trip.
  const MailFolder.inbox()
    : path = kInboxPath,
      name = kInboxPath,
      role = MailFolderRole.inbox,
      isSelectable = true;

  final String path;
  final String name;
  final MailFolderRole role;

  /// Some servers expose container-only nodes that hold no messages.
  final bool isSelectable;

  bool get isInbox => role == MailFolderRole.inbox;

  @override
  bool operator ==(Object other) =>
      other is MailFolder && other.path == path && other.name == name;

  @override
  int get hashCode => Object.hash(path, name);
}
