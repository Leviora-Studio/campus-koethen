// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:campus_koethen/features/moodle/domain/moodle_profile.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const MoodleProfile profile = MoodleProfile();

  test('allows only the exact Moodle HTTPS origin', () {
    expect(
      profile.allows(Uri.parse('${profile.baseUrl}/course/view.php')),
      isTrue,
    );
    expect(
      profile.allows(
        Uri.parse('https://${profile.host.toUpperCase()}/course/view.php'),
      ),
      isTrue,
    );
    expect(
      profile.allows(Uri.parse('https://${profile.host}:443/pluginfile.php/1')),
      isTrue,
    );
  });

  test('rejects alternate ports, user-info, plaintext and relative URLs', () {
    expect(
      profile.allows(Uri.parse('https://${profile.host}:8443/steal')),
      isFalse,
    );
    expect(
      profile.allows(Uri.parse('https://user:password@${profile.host}/steal')),
      isFalse,
    );
    expect(profile.allows(Uri.parse('http://${profile.host}/steal')), isFalse);
    expect(profile.allows(Uri.parse('/webservice/rest/server.php')), isFalse);
  });
}
