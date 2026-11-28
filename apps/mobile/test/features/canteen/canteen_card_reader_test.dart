import 'dart:typed_data';

import 'package:campus_koethen/features/canteen/data/canteen_card_reader.dart';
import 'package:flutter/services.dart' show MethodChannel, PlatformException;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('decodes signed amounts and rounds to integer cents', () {
    Uint8List littleEndian(int value) {
      final bytes = ByteData(4)..setInt32(0, value, Endian.little);
      return bytes.buffer.asUint8List();
    }

    expect(decodeCanteenCardCents(littleEndian(12340)), 1234);
    expect(decodeCanteenCardCents(littleEndian(12345)), 1235);
    expect(decodeCanteenCardCents(littleEndian(-12345)), -1235);
    expect(decodeCanteenCardCents(littleEndian(0)), 0);
  });

  test('stores only a successful amount and its timestamp', () async {
    FlutterSecureStorage.setMockInitialValues({});
    const channel = MethodChannel('campus_koethen/mensa_card');
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    addTearDown(() => messenger.setMockMethodCallHandler(channel, null));
    const reader = CanteenCardReader();
    expect(await reader.lastRead(), isNull);

    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'scan');
      return Uint8List.fromList([0x34, 0x30, 0, 0]);
    });
    final balance = await reader.scan('Demo scan');
    expect(balance.cents, 1234);
    expect(balance.readAt.isUtc, isTrue);
    expect(await reader.lastRead(), balance);

    messenger.setMockMethodCallHandler(channel, (_) async {
      throw PlatformException(code: 'readFailed');
    });
    await expectLater(
      reader.scan('Demo scan'),
      throwsA(isA<PlatformException>()),
    );
    expect(await reader.lastRead(), balance);
  });
}
