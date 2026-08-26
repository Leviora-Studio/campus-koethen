// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'package:flutter/foundation.dart' show compute;
import 'package:html/dom.dart';
import 'package:html/parser.dart' as html;

import '../domain/grade.dart';
import '../domain/grade_failure.dart';

/// Which grade-table column a header maps to.
enum _Column {
  examNumber,
  title,
  grade,
  points,
  status,
  bonus,
  attempt,
  examDate,
  examiner,
}

/// Parses HIS-QIS HTML into domain objects using a real DOM parser (no regex
/// over general HTML).
///
/// The grades table is found by its column headers, never by a CSS class or a
/// fixed id. If the required columns are not all present the parser reports a
/// [GradeFailureKind.portalStructureChanged] and NEVER returns a partial table.
/// Nothing here logs the HTML.
///
/// Every method that parses HTML (`html.parse`) does so on a background
/// isolate via [compute] — parsing and extraction are pure functions of the
/// HTML string, with no I/O and no Flutter dependency, so they are safe to
/// run off the UI isolate. Each public method is therefore `Future`-returning
/// even though the underlying work is synchronous, and delegates to a
/// private `_...Sync` static method that does the actual parsing — that
/// private method is what actually runs on the background isolate.
abstract final class QisHtmlParser {
  static const Set<_Column> _required = <_Column>{
    _Column.examNumber,
    _Column.title,
    _Column.grade,
    _Column.status,
  };

  /// True when the page still shows the login form (fields `asdf` / `fdsa`).
  static Future<bool> hasLoginForm(String htmlSource) =>
      compute(_hasLoginFormSync, htmlSource);

  static bool _hasLoginFormSync(String htmlSource) {
    final Document doc = html.parse(htmlSource);
    return doc.querySelector('input[name="asdf"]') != null &&
        doc.querySelector('input[name="fdsa"]') != null;
  }

  /// True when the page is authenticated (a logout link is present).
  static Future<bool> isAuthenticated(String htmlSource) async =>
      await logoutHref(htmlSource) != null;

  /// The QIS logout link, if any.
  static Future<String?> logoutHref(String htmlSource) =>
      compute(_logoutHrefSync, htmlSource);

  static String? _logoutHrefSync(String htmlSource) {
    final Document doc = html.parse(htmlSource);
    for (final Element a in doc.querySelectorAll('a[href]')) {
      final String href = a.attributes['href'] ?? '';
      final String text = _norm(a.text).toLowerCase();
      if (href.toLowerCase().contains('auth.logout') ||
          text == 'abmelden' ||
          text == 'logout') {
        return href;
      }
    }
    return null;
  }

  /// The href of the first `<a>` whose visible text (or `title`) contains any of
  /// [labels] (case-insensitive). Returns the raw href, including the session
  /// `asi` the portal put there.
  static Future<String?> findLinkHref(
    String htmlSource, {
    required List<String> labels,
  }) => compute(_findLinkHrefSync, (htmlSource, labels));

  static String? _findLinkHrefSync((String, List<String>) args) {
    final String htmlSource = args.$1;
    final List<String> labels = args.$2;
    final List<String> needles = labels
        .map((String l) => l.toLowerCase())
        .toList();
    final Document doc = html.parse(htmlSource);
    for (final Element a in doc.querySelectorAll('a[href]')) {
      final String text = _norm(a.text).toLowerCase();
      final String title = _norm(a.attributes['title'] ?? '').toLowerCase();
      if (needles.any((String n) => text.contains(n) || title.contains(n))) {
        return a.attributes['href'];
      }
    }
    return null;
  }

  /// Extracts the dynamic `asi` value from a URL. Never persisted by callers.
  static String? extractAsi(String url) {
    final int q = url.indexOf('?');
    final String query = q >= 0 ? url.substring(q + 1) : url;
    for (final String pair in query.split('&')) {
      final int eq = pair.indexOf('=');
      if (eq <= 0) continue;
      if (pair.substring(0, eq) == 'asi') return pair.substring(eq + 1);
    }
    return null;
  }

  /// Parses the Notenspiegel table. Throws [GradeFailure] with
  /// [GradeFailureKind.portalStructureChanged] when no valid table is found.
  static Future<GradeReport> parseGradeReport(String htmlSource) =>
      compute(_parseGradeReportSync, htmlSource);

  static GradeReport _parseGradeReportSync(String htmlSource) {
    final Document doc = html.parse(htmlSource);
    for (final Element table in doc.querySelectorAll('table')) {
      final Map<_Column, int>? mapping = _headerMapping(table);
      if (mapping == null) continue;
      return GradeReport(_rows(table, mapping));
    }
    throw const GradeFailure(GradeFailureKind.portalStructureChanged);
  }

  // --- internals ------------------------------------------------------------

  static Map<_Column, int>? _headerMapping(Element table) {
    // The header row is the first row that has any <th>, else the first row.
    final List<Element> rows = table.querySelectorAll('tr');
    Element? headerRow;
    for (final Element row in rows) {
      if (row.querySelector('th') != null) {
        headerRow = row;
        break;
      }
    }
    headerRow ??= rows.isNotEmpty ? rows.first : null;
    if (headerRow == null) return null;

    final List<Element> cells = headerRow.querySelectorAll('th, td');
    final Map<_Column, int> mapping = <_Column, int>{};
    for (int i = 0; i < cells.length; i++) {
      final _Column? column = _columnOf(_norm(cells[i].text).toLowerCase());
      // First header wins for a given column, so a later stray match cannot
      // overwrite the real one.
      if (column != null && !mapping.containsKey(column)) {
        mapping[column] = i;
      }
    }
    if (!_required.every(mapping.containsKey)) return null;
    return mapping;
  }

  /// Maps a normalised header to a column. The specific headers are checked
  /// before the generic `prüfung`/`note`, so `Prüfungsnummer` is not mistaken
  /// for the title, etc.
  static _Column? _columnOf(String header) {
    if (header.contains('prüfungsnummer') ||
        header == 'nr' ||
        header == 'pnr') {
      return _Column.examNumber;
    }
    if (header.contains('prüfungstext')) return _Column.title;
    if (header.contains('prüfungsdatum') || header == 'datum') {
      return _Column.examDate;
    }
    if (header.contains('prüfer')) return _Column.examiner;
    if (header.contains('note')) return _Column.grade;
    if (header.contains('punkte')) return _Column.points;
    if (header.contains('status')) return _Column.status;
    if (header.contains('bonus')) return _Column.bonus;
    if (header.contains('versuch')) return _Column.attempt;
    if (header.contains('prüfung')) return _Column.title; // generic fallback
    return null;
  }

  static List<GradeEntry> _rows(Element table, Map<_Column, int> mapping) {
    final int lastNeeded = mapping.values.fold(
      0,
      (int a, int b) => a > b ? a : b,
    );
    final List<GradeEntry> entries = <GradeEntry>[];

    for (final Element row in table.querySelectorAll('tr')) {
      // Skip the header row.
      if (row.querySelector('th') != null) continue;
      final List<Element> cells = row.querySelectorAll('td');
      if (cells.length <= lastNeeded) continue;

      String cell(_Column c) => _norm(cells[mapping[c]!].text);
      String? optional(_Column c) {
        final int? i = mapping[c];
        if (i == null) return null;
        final String v = _norm(cells[i].text);
        return v.isEmpty ? null : v;
      }

      final String examNumber = cell(_Column.examNumber);
      final String title = cell(_Column.title);
      // Drop spacer rows that carry neither a number nor a title.
      if (examNumber.isEmpty && title.isEmpty) continue;

      final String statusText = cell(_Column.status);
      final ExamStatus status = _parseStatus(statusText);

      entries.add(
        GradeEntry(
          examNumber: examNumber,
          title: title,
          grade: _parseGrade(cell(_Column.grade), status),
          status: status,
          statusText: statusText,
          points: optional(_Column.points),
          bonus: optional(_Column.bonus),
          attempt: optional(_Column.attempt),
          examDate: _parseDate(cell(_Column.examDate)),
          examiner: optional(_Column.examiner),
        ),
      );
    }
    return entries;
  }

  static Grade _parseGrade(String raw, ExamStatus status) {
    final double? numeric = raw.isEmpty
        ? null
        : double.tryParse(raw.replaceAll(',', '.'));
    // A real German grade is > 0. Empty or 0,0 is NOT a numeric grade.
    if (numeric != null && numeric > 0) return Grade.graded(numeric);
    if (status == ExamStatus.passed) return const Grade.passedUngraded();
    return const Grade.none();
  }

  static ExamStatus _parseStatus(String raw) {
    final String t = raw.toLowerCase();
    // "nicht bestanden" must be checked before "bestanden".
    if (t.contains('nicht bestanden') || t == 'nb') return ExamStatus.failed;
    if (t.contains('bestanden') || t == 'be') return ExamStatus.passed;
    if (t.contains('prüfung vorhanden') || t == 'pv') return ExamStatus.present;
    return ExamStatus.unknown;
  }

  static final RegExp _datePattern = RegExp(r'^(\d{2})\.(\d{2})\.(\d{4})$');

  static DateTime? _parseDate(String raw) {
    final RegExpMatch? m = _datePattern.firstMatch(raw.trim());
    if (m == null) return null;
    final int day = int.parse(m.group(1)!);
    final int month = int.parse(m.group(2)!);
    final int year = int.parse(m.group(3)!);
    final DateTime dt = DateTime(year, month, day);
    // Reject impossible dates that DateTime silently rolls over.
    if (dt.day != day || dt.month != month) return null;
    return dt;
  }

  static final RegExp _whitespacePattern = RegExp(r'\s+');

  /// Collapses all whitespace (incl. non-breaking spaces) to single spaces and
  /// trims. `element.text` already decodes HTML entities.
  static String _norm(String raw) =>
      raw.replaceAll(' ', ' ').replaceAll(_whitespacePattern, ' ').trim();
}
