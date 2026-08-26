// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:flutter/foundation.dart';

import 'request_drafts.dart';

/// A case that left the device and is now tracked locally.
///
/// **[statusUrl] is a bearer credential.** It is the only way anyone reaches
/// this case, it authenticates nobody, and holding it is holding the case. It
/// is stored encrypted, sent only to the configured status endpoint, and never
/// logged, never put in a route, never shared, never reported. The same is true
/// of [receiptPdfUrl], which carries the same token.
///
/// What is kept here is the *submission*, not the *status*: the status endpoint
/// answers `Cache-Control: no-store`, so a response is held in memory for as
/// long as a screen shows it and is fetched again next time. Offline, the app
/// says it has no current status rather than presenting yesterday's as today's.
@immutable
class SubmittedCase {
  const SubmittedCase({
    required this.id,
    required this.kind,
    required this.submittedAt,
    required this.statusUrl,
    required this.receiptPdfUrl,
    this.number,
    this.localTitle = '',
    this.wasReplay = false,
  });

  /// Local identifier. This — and only this — is what a route carries.
  final String id;

  final RequestKind kind;

  /// When the device recorded the successful submission.
  final DateTime submittedAt;

  /// Secret status link.
  final String statusUrl;

  /// Receipt PDF, same token, equally secret.
  final String receiptPdfUrl;

  /// Case number, or `null` where the board's numbering is off.
  final String? number;

  /// What the user called it, kept from the draft.
  ///
  /// Exists so the list has something to show before the first status response
  /// arrives, and offline. The server's own title wins wherever both are known.
  final String localTitle;

  /// True when the endpoint replayed an earlier submission for the same key.
  /// Nothing was filed twice — worth saying so plainly.
  final bool wasReplay;

  SubmittedCase copyWith({String? number, String? localTitle}) => SubmittedCase(
    id: id,
    kind: kind,
    submittedAt: submittedAt,
    statusUrl: statusUrl,
    receiptPdfUrl: receiptPdfUrl,
    number: number ?? this.number,
    localTitle: localTitle ?? this.localTitle,
    wasReplay: wasReplay,
  );

  Map<String, dynamic> toJson() => <String, dynamic>{
    'id': id,
    'kind': kind.storageValue,
    'submittedAt': submittedAt.toIso8601String(),
    'statusUrl': statusUrl,
    'receiptPdfUrl': receiptPdfUrl,
    if (number != null) 'number': number,
    'localTitle': localTitle,
    'wasReplay': wasReplay,
  };

  static SubmittedCase? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final Object? id = json['id'];
    final RequestKind? kind = RequestKind.fromStorage(
      json['kind'] is String ? json['kind'] as String : null,
    );
    final Object? statusUrl = json['statusUrl'];
    final Object? receipt = json['receiptPdfUrl'];
    if (id is! String || kind == null) return null;
    // Without the link there is no way back to this case; a record without one
    // could never be refreshed and would be a permanent dead entry.
    if (statusUrl is! String || statusUrl.trim().isEmpty) return null;
    return SubmittedCase(
      id: id,
      kind: kind,
      submittedAt:
          DateTime.tryParse(
            json['submittedAt'] is String ? json['submittedAt'] as String : '',
          ) ??
          DateTime(2026),
      statusUrl: statusUrl,
      receiptPdfUrl: receipt is String ? receipt : '',
      number: json['number'] is String ? json['number'] as String : null,
      localTitle: json['localTitle'] is String
          ? json['localTitle'] as String
          : '',
      wasReplay: json['wasReplay'] is bool && json['wasReplay'] as bool,
    );
  }

  /// Deliberately without the links: this is what ends up in log lines and
  /// error reports.
  @override
  String toString() => 'SubmittedCase($id, ${kind.storageValue}, $number)';
}
