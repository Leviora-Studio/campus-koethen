// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/mail_cache_store.dart';
import 'mail_providers.dart';
import 'mail_sync_controller.dart';

/// Every correspondent seen in the cached mail history, for recipient
/// suggestions. Rebuilds as the cache grows.
final FutureProvider<List<MailAddressEntry>> mailKnownAddressesProvider =
    FutureProvider<List<MailAddressEntry>>((Ref ref) async {
      ref.watch(mailCacheRevisionProvider);
      return ref.read(mailCacheStoreProvider).knownAddresses();
    });

/// Ranks [all] against a query: an address whose email or name contains the
/// query (case-insensitive), best matches first, capped for a compact list.
List<MailAddressEntry> suggestRecipients(
  List<MailAddressEntry> all,
  String query, {
  int limit = 6,
}) {
  final String q = query.trim().toLowerCase();
  if (q.isEmpty) return const <MailAddressEntry>[];

  final List<MailAddressEntry> matches = all.where((MailAddressEntry e) {
    final String email = e.email.toLowerCase();
    final String name = (e.name ?? '').toLowerCase();
    return email.contains(q) || name.contains(q);
  }).toList();

  matches.sort((MailAddressEntry a, MailAddressEntry b) {
    // Prefix matches on the email rank above substring matches.
    final bool aPrefix = a.email.toLowerCase().startsWith(q);
    final bool bPrefix = b.email.toLowerCase().startsWith(q);
    if (aPrefix != bPrefix) return aPrefix ? -1 : 1;
    return a.email.toLowerCase().compareTo(b.email.toLowerCase());
  });
  return matches.take(limit).toList();
}
