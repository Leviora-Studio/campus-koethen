// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:meta/meta.dart';

/// The kind of a course module. Unknown/unsupported kinds degrade gracefully to
/// [unknown] rather than being dropped — the UI shows them as "not supported".
enum MoodleModuleType {
  resource,
  folder,
  page,
  url,
  label,
  assign,
  forum,
  quiz,
  book,
  lesson,
  feedback,
  choice,
  unknown;

  static MoodleModuleType fromRaw(String raw) {
    switch (raw) {
      case 'resource':
        return MoodleModuleType.resource;
      case 'folder':
        return MoodleModuleType.folder;
      case 'page':
        return MoodleModuleType.page;
      case 'url':
        return MoodleModuleType.url;
      case 'label':
        return MoodleModuleType.label;
      case 'assign':
        return MoodleModuleType.assign;
      case 'forum':
        return MoodleModuleType.forum;
      case 'quiz':
        return MoodleModuleType.quiz;
      case 'book':
        return MoodleModuleType.book;
      case 'lesson':
        return MoodleModuleType.lesson;
      case 'feedback':
        return MoodleModuleType.feedback;
      case 'choice':
        return MoodleModuleType.choice;
      default:
        return MoodleModuleType.unknown;
    }
  }
}

/// A downloadable file inside a module. [fileUrl] is a Moodle `pluginfile` URL
/// that requires the token — it is only ever fetched through the guarded
/// downloader, never opened in an external browser with the token attached.
@immutable
class MoodleFile {
  const MoodleFile({
    required this.fileName,
    required this.fileUrl,
    this.mimeType,
    this.fileSize,
    this.timeModified,
  });

  final String fileName;
  final String fileUrl;
  final String? mimeType;
  final int? fileSize;
  final DateTime? timeModified;

  @override
  bool operator ==(Object other) =>
      other is MoodleFile &&
      other.fileName == fileName &&
      other.fileUrl == fileUrl &&
      other.mimeType == mimeType &&
      other.fileSize == fileSize &&
      other.timeModified == timeModified;

  @override
  int get hashCode =>
      Object.hash(fileName, fileUrl, mimeType, fileSize, timeModified);
}

/// A single activity/resource in a section.
@immutable
class MoodleModule {
  const MoodleModule({
    required this.id,
    required this.name,
    required this.type,
    this.rawType = '',
    this.description = '',
    this.url,
    this.visible = true,
    this.availabilityInfo,
    this.files = const <MoodleFile>[],
    this.instanceId,
  });

  final int id;
  final String name;
  final MoodleModuleType type;
  final String rawType;

  /// Safe plain text (no HTML/scripts).
  final String description;

  /// An external link for `url` modules (opened WITHOUT any token).
  final String? url;

  final bool visible;
  final String? availabilityInfo;
  final List<MoodleFile> files;

  /// The activity instance id (e.g. assignment id) when applicable.
  final int? instanceId;

  @override
  bool operator ==(Object other) =>
      other is MoodleModule &&
      other.id == id &&
      other.name == name &&
      other.type == type &&
      other.rawType == rawType &&
      other.description == description &&
      other.url == url &&
      other.visible == visible &&
      other.availabilityInfo == availabilityInfo &&
      other.instanceId == instanceId &&
      _listEquals(other.files, files);

  @override
  int get hashCode => Object.hash(
    id,
    name,
    type,
    rawType,
    description,
    url,
    visible,
    availabilityInfo,
    instanceId,
    Object.hashAll(files),
  );
}

/// A course section grouping modules.
@immutable
class MoodleSection {
  const MoodleSection({
    required this.name,
    this.summary = '',
    this.visible = true,
    this.modules = const <MoodleModule>[],
  });

  final String name;
  final String summary;
  final bool visible;
  final List<MoodleModule> modules;

  @override
  bool operator ==(Object other) =>
      other is MoodleSection &&
      other.name == name &&
      other.summary == summary &&
      other.visible == visible &&
      _listEquals(other.modules, modules);

  @override
  int get hashCode =>
      Object.hash(name, summary, visible, Object.hashAll(modules));
}

bool _listEquals<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (int i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
