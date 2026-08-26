// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:campus_koethen/features/notifications/data/local_notification_gateway.dart';
import 'package:campus_koethen/features/notifications/domain/notification_permission.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel channel = MethodChannel(
    'dexterous.com/flutter/local_notifications',
  );

  setUp(() {
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
          if (call.method == 'areNotificationsEnabled' ||
              call.method == 'requestNotificationsPermission') {
            throw PlatformException(code: 'unavailable');
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('a failed permission status read fails closed', () async {
    final LocalNotificationGateway gateway = LocalNotificationGateway(
      targetPlatform: TargetPlatform.android,
    );

    expect(
      await gateway.permissionStatus(),
      NotificationPermissionStatus.denied,
    );
  });

  test(
    'a failed permission request cannot become a successful opt-in',
    () async {
      final LocalNotificationGateway gateway = LocalNotificationGateway(
        targetPlatform: TargetPlatform.android,
      );

      expect(
        await gateway.requestPermission(),
        NotificationPermissionStatus.denied,
      );
    },
  );
}
