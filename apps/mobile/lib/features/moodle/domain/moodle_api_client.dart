// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'moodle_account.dart';
import 'moodle_announcement.dart';
import 'moodle_assignment.dart';
import 'moodle_content.dart';
import 'moodle_course.dart';
import 'moodle_deadline.dart';

/// Port: the low-level, read-only Moodle Web Services the app wraps.
///
/// Every method talks directly and only to `moodle.hs-anhalt.de`. There are no
/// write functions and no generic "call any function" escape hatch — only the
/// specific reads the features need. All calls take the token as an argument;
/// the concrete client sends it in the POST body, never in a query string, and
/// never to any other host.
abstract interface class MoodleApiClient {
  /// `POST /login/token.php` — exchanges credentials for a token. The password
  /// is used for this single call and then discarded by the caller.
  Future<String> requestToken({
    required String username,
    required String password,
  });

  /// `core_webservice_get_site_info` — verifies a token and yields the user id.
  Future<MoodleSiteInfo> getSiteInfo(String token);

  /// `core_course_get_enrolled_courses_by_timeline_classification` — courses
  /// Moodle classifies as in progress for the current user.
  Future<List<MoodleCourse>> getCourses({required String token});

  /// `core_course_get_contents` — sections and modules of one course.
  Future<List<MoodleSection>> getCourseContents({
    required String token,
    required int courseId,
  });

  /// `mod_assign_get_assignments` — assignments for the given courses.
  Future<List<MoodleAssignment>> getAssignments({
    required String token,
    required List<int> courseIds,
  });

  /// `mod_assign_get_submission_status` — read-only status for one assignment.
  Future<MoodleSubmissionStatus> getSubmissionStatus({
    required String token,
    required int assignmentId,
  });

  /// News-forum announcements for one course (forums → discussions).
  Future<List<MoodleAnnouncement>> getAnnouncements({
    required String token,
    required int courseId,
  });

  /// `core_calendar_get_action_events_by_timesort` — upcoming dated events.
  Future<List<MoodleDeadline>> getUpcomingDeadlines({
    required String token,
    DateTime? from,
    int limit = 50,
  });
}
