// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'dart:convert';
import 'dart:typed_data' show Endian;

import 'package:flutter/services.dart';

import '../../../core/security/app_secure_storage.dart';

typedef CanteenCardBalance = ({int cents, DateTime readAt});

class CanteenCardReader {
  const CanteenCardReader();

  static const _channel = MethodChannel('campus_koethen/mensa_card');
  static const _storageKey = 'canteen.card.last_balance.v1';

  Future<CanteenCardBalance?> lastRead() async {
    final saved = await appSecureStorage().read(key: _storageKey);
    if (saved == null) return null;
    final decoded = jsonDecode(saved);
    if (decoded case {'cents': final int cents, 'readAt': final String value}) {
      final readAt = DateTime.tryParse(value);
      if (readAt != null) return (cents: cents, readAt: readAt);
    }
    return null;
  }

  Future<CanteenCardBalance> scan(String instructions) async {
    final data = await _channel.invokeMethod<Uint8List>('scan', {
      'instructions': instructions,
    });
    if (data == null || data.length != 4) {
      throw PlatformException(code: 'readFailed');
    }
    final balance = (
      cents: decodeCanteenCardCents(data),
      readAt: DateTime.now().toUtc(),
    );
    await appSecureStorage().write(
      key: _storageKey,
      value: jsonEncode({
        'cents': balance.cents,
        'readAt': balance.readAt.toIso8601String(),
      }),
    );
    return balance;
  }

  Future<void> cancel() => _channel.invokeMethod<void>('cancel');
}

/// The purse stores a signed little-endian value in thousandths of a euro.
int decodeCanteenCardCents(Uint8List data) {
  final mills = ByteData.sublistView(data).getInt32(0, Endian.little);
  final cents = (mills.abs() + 5) ~/ 10;
  return mills.isNegative ? -cents : cents;
}
