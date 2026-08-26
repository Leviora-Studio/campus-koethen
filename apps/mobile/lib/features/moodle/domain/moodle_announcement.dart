// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:meta/meta.dart';

/// A forum announcement (news-forum discussion) within a course.
@immutable
class MoodleAnnouncement {
  const MoodleAnnouncement({
    required this.id,
    required this.courseId,
    required this.subject,
    this.message = '',
    this.authorName,
    this.createdAt,
    this.links = const <String>[],
  });

  final int id;
  final int courseId;
  final String subject;

  /// Safe plain text (no HTML/scripts).
  final String message;

  final String? authorName;
  final DateTime? createdAt;

  /// Absolute http(s) targets recovered from the original HTML before it was
  /// reduced to plain text. Shown as buttons under the message so the link is
  /// still reachable without rendering any markup.
  final List<String> links;

  @override
  bool operator ==(Object other) =>
      other is MoodleAnnouncement &&
      other.id == id &&
      other.courseId == courseId &&
      other.subject == subject &&
      other.message == message &&
      other.authorName == authorName &&
      other.createdAt == createdAt &&
      _sameLinks(other.links, links);

  static bool _sameLinks(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hash(
    id,
    courseId,
    subject,
    message,
    authorName,
    createdAt,
    Object.hashAll(links),
  );
}
