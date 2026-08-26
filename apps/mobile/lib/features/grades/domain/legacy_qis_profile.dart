// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'grade_portal.dart';
import 'grade_portal_profile.dart';

/// The pinned HIS-QIS (legacy) exam-portal endpoints of Hochschule Anhalt.
///
/// This is the single source of truth for the ONE host the legacy grades
/// gateway is allowed to talk to. Every request is validated against
/// [allows]; anything that is not HTTPS on exactly [host] is refused.
class LegacyQisProfile implements GradePortalProfile {
  const LegacyQisProfile();

  @override
  GradePortal get portal => GradePortal.hisQisLegacy;

  @override
  String get scheme => 'https';

  @override
  String get host => 'service.ssc.hs-anhalt.de';

  @override
  String get baseUrl => 'https://service.ssc.hs-anhalt.de';

  @override
  String get portalUrl =>
      'https://service.ssc.hs-anhalt.de/qisserver/rds?state=user&type=0';

  @override
  String get loginUrl =>
      'https://service.ssc.hs-anhalt.de/qisserver/rds'
      '?state=user&type=1&category=auth.login&startpage=portal.vm';

  @override
  String get logoutUrl =>
      'https://service.ssc.hs-anhalt.de/qisserver/rds'
      '?state=user&type=4&category=auth.logout';

  @override
  bool allows(Uri uri) => gradePortalAllows(uri, scheme: scheme, host: host);
}
