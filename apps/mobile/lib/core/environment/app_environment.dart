// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import '../network/json.dart';

/// Public flags describing the Campus API deployment the app is connected to.
class AppEnvironment {
  const AppEnvironment({required this.userTestData});

  final bool userTestData;

  static AppEnvironment fromJson(Object? json) {
    final Map<String, dynamic>? map = asJsonMap(json);
    return AppEnvironment(userTestData: map?['userTestData'] == true);
  }
}
