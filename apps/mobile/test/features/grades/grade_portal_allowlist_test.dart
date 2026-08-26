// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:campus_koethen/features/grades/domain/his_in_one_profile.dart';
import 'package:campus_koethen/features/grades/domain/legacy_qis_profile.dart';
import 'package:campus_koethen/features/grades/domain/grade_portal_profile.dart';
import 'package:flutter_test/flutter_test.dart';

/// The two exam portals keep separate allowlists on purpose, so both are
/// checked against the same rules here — a hole opened in one must not be
/// able to hide behind the other passing.
void main() {
  final List<GradePortalProfile> profiles = <GradePortalProfile>[
    const HisInOneProfile(),
    const LegacyQisProfile(),
  ];

  for (final GradePortalProfile profile in profiles) {
    group('${profile.portal.name} allowlist', () {
      test('accepts its own origin', () {
        expect(
          profile.allows(Uri.parse('https://${profile.host}/qisserver/rds')),
          isTrue,
        );
        // An explicit default port is the same origin.
        expect(
          profile.allows(Uri.parse('https://${profile.host}:443/x')),
          isTrue,
        );
      });

      test('refuses another host and another scheme', () {
        expect(profile.allows(Uri.parse('https://evil.example/x')), isFalse);
        expect(profile.allows(Uri.parse('http://${profile.host}/x')), isFalse);
      });

      test('refuses a non-default port on the same host', () {
        // S-10: the check was `scheme == scheme && host == host`, so a
        // redirect to :8443 on the right host was accepted — same name,
        // different service.
        expect(
          profile.allows(Uri.parse('https://${profile.host}:8443/x')),
          isFalse,
        );
      });

      test('refuses credentials in the authority', () {
        // S-10: `https://evil@host/` parses with the expected host and is the
        // classic way to make a URL read as one origin and point at another.
        expect(
          profile.allows(Uri.parse('https://evil@${profile.host}/x')),
          isFalse,
        );
        expect(
          profile.allows(Uri.parse('https://a:b@${profile.host}/x')),
          isFalse,
        );
      });

      test('is case-insensitive on the host, because DNS is', () {
        expect(
          profile.allows(Uri.parse('https://${profile.host.toUpperCase()}/x')),
          isTrue,
        );
      });

      test('refuses a relative reference', () {
        expect(profile.allows(Uri.parse('/qisserver/rds')), isFalse);
      });
    });
  }

  test('the two portals never accept each other', () {
    const HisInOneProfile hisInOne = HisInOneProfile();
    const LegacyQisProfile legacy = LegacyQisProfile();
    expect(hisInOne.allows(Uri.parse('https://${legacy.host}/x')), isFalse);
    expect(legacy.allows(Uri.parse('https://${hisInOne.host}/x')), isFalse);
  });
}
