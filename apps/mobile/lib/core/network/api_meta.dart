// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'json.dart';

/// Pagination block of a list response (`meta.pagination`).
class ApiPagination {
  const ApiPagination({
    required this.page,
    required this.pageSize,
    required this.total,
    required this.totalPages,
  });

  final int page;
  final int pageSize;
  final int total;
  final int totalPages;

  bool get hasNextPage => page < totalPages;

  static ApiPagination? fromJson(Object? json) {
    final Map<String, dynamic>? map = asJsonMap(json);
    if (map == null) return null;
    return ApiPagination(
      page: asInt(map['page']) ?? 1,
      pageSize: asInt(map['pageSize']) ?? 0,
      total: asInt(map['total']) ?? 0,
      totalPages: asInt(map['totalPages']) ?? 0,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'page': page,
    'pageSize': pageSize,
    'total': total,
    'totalPages': totalPages,
  };
}

/// The `meta` envelope every content response carries.
class ApiMeta {
  const ApiMeta({
    this.requestedLocale,
    this.resolvedLocale,
    this.translationFallback = false,
    this.pagination,
    this.lastSuccessfulSyncAt,
    this.dataStale = false,
    this.featureEnabled,
    this.dataState,
    this.droppedBlockTypes = const <String>[],
    this.from,
    this.to,
    this.truncated = false,
  });

  final String? requestedLocale;
  final String? resolvedLocale;

  /// `true` when at least one delivered field fell back to the German source.
  final bool translationFallback;

  final ApiPagination? pagination;

  /// Canteen responses only. `null` means: never successfully synchronised.
  final DateTime? lastSuccessfulSyncAt;

  /// Canteen and timetable responses only.
  final bool dataStale;

  /// Timetable responses only: whether the feature is switched on at all.
  /// `null` when the endpoint does not carry the flag.
  final bool? featureEnabled;

  /// Timetable responses only: the raw `dataState` key
  /// (`ready` | `pending` | `unavailable`). Kept as a string here so this core
  /// type stays free of feature specific enums; the timetable feature maps it.
  final String? dataState;

  /// Block types the server dropped from rich text content.
  final List<String> droppedBlockTypes;

  /// The server-resolved start of a date-bounded response's window
  /// (`YYYY-MM-DD`), e.g. for `/v1/posts/events` or `/v1/calendars/events`.
  /// Always read back from the response, never assumed from the request —
  /// the client sends no default window of its own.
  final String? from;

  /// The server-resolved end of the window, matching [from].
  final String? to;

  /// `true` when the server hit its own result ceiling and cut the list short.
  /// The UI has to say so rather than present the result as complete.
  final bool truncated;

  static const ApiMeta empty = ApiMeta();

  static ApiMeta fromJson(Object? json) {
    final Map<String, dynamic>? map = asJsonMap(json);
    if (map == null) return empty;
    return ApiMeta(
      requestedLocale: asString(map['requestedLocale']),
      resolvedLocale: asString(map['resolvedLocale']),
      translationFallback: asBool(map['translationFallback']) ?? false,
      pagination: ApiPagination.fromJson(map['pagination']),
      lastSuccessfulSyncAt: asDateTime(map['lastSuccessfulSyncAt']),
      dataStale: asBool(map['dataStale']) ?? false,
      featureEnabled: asBool(map['featureEnabled']),
      dataState: asString(map['dataState']),
      droppedBlockTypes: asStringList(map['droppedBlockTypes']),
      from: asString(map['from']),
      to: asString(map['to']),
      truncated: asBool(map['truncated']) ?? false,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'requestedLocale': requestedLocale,
    'resolvedLocale': resolvedLocale,
    'translationFallback': translationFallback,
    if (pagination != null) 'pagination': pagination!.toJson(),
    if (lastSuccessfulSyncAt != null)
      'lastSuccessfulSyncAt': lastSuccessfulSyncAt!.toUtc().toIso8601String(),
    'dataStale': dataStale,
    if (featureEnabled != null) 'featureEnabled': featureEnabled,
    if (dataState != null) 'dataState': dataState,
    'droppedBlockTypes': droppedBlockTypes,
    if (from != null) 'from': from,
    if (to != null) 'to': to,
    'truncated': truncated,
  };
}

/// A parsed content response: payload plus its [ApiMeta].
class ApiResponse<T> {
  const ApiResponse({required this.data, required this.meta});

  final T data;
  final ApiMeta meta;

  ApiResponse<R> map<R>(R Function(T value) transform) =>
      ApiResponse<R>(data: transform(data), meta: meta);
}
