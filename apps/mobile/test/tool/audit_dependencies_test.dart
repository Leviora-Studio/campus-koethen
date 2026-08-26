// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import '../../tool/audit_dependencies.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'dependency audit blocks high, critical and unclassified advisories',
    () {
      expect(severityBlocksBuild('HIGH'), isTrue);
      expect(severityBlocksBuild('critical'), isTrue);
      expect(severityBlocksBuild('UNKNOWN'), isTrue);
    },
  );

  test('dependency audit does not block an explicitly lower severity', () {
    expect(severityBlocksBuild('MODERATE'), isFalse);
    expect(severityBlocksBuild('LOW'), isFalse);
  });
}
