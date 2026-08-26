// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

/// Checks every locked Dart/Flutter dependency against the OSV database.
///
/// `pnpm audit --audit-level high` guards the Node side of the repository and
/// nothing guarded the Dart side (S-12) — even though `enough_mail`, `dio`,
/// `flutter_secure_storage`, `hive_ce` and `url_launcher` are precisely the
/// packages that touch credentials and personal content.
///
/// Uses the public OSV batch API rather than a downloaded scanner binary: no
/// extra binary to pin, verify and keep current, and the query needs nothing
/// but the lockfile that is already in the repository. Only package names and
/// versions leave the runner — no source, no lockfile hashes.
///
/// Exit codes:
///
/// * `0` — no advisory at or above the requested severity.
/// * `1` — at least one advisory. Every finding is printed with its id, the
///   package and a link.
/// * `2` — the audit could not be completed (lockfile unreadable, OSV
///   unreachable, unexpected response). Deliberately NOT `0`: an audit that
///   did not run must never read as an audit that found nothing.
///
/// `--allow-network-failure` downgrades exit code 2 to a warning, for a run
/// that must not be blocked by an outage of a third-party service. The default
/// is to fail, because that is the honest reading.
library;

import 'dart:convert';
import 'dart:io';

const String _osvBatchUrl = 'https://api.osv.dev/v1/querybatch';
const String _osvVulnUrl = 'https://api.osv.dev/v1/vulns';

/// Severities that fail the build, mirroring `--audit-level high` on the Node
/// side. `UNKNOWN` also blocks deliberately: an advisory whose detail lookup
/// failed or whose source supplied no trusted classification must never be
/// mistaken for a clean dependency set.
const Set<String> _blocking = <String>{'HIGH', 'CRITICAL', 'UNKNOWN'};

/// Public for the regression test; the audit itself remains a standalone tool.
bool severityBlocksBuild(String severity) =>
    _blocking.contains(severity.toUpperCase());

Future<int> main(List<String> args) async {
  final bool allowNetworkFailure = args.contains('--allow-network-failure');

  final File lockfile = File('pubspec.lock');
  if (!lockfile.existsSync()) {
    stderr.writeln('audit: pubspec.lock not found — run from apps/mobile.');
    return 2;
  }

  final Map<String, String> packages;
  try {
    packages = _parseLockfile(lockfile.readAsLinesSync());
  } catch (error) {
    stderr.writeln('audit: could not read pubspec.lock: $error');
    return 2;
  }
  if (packages.isEmpty) {
    stderr.writeln('audit: pubspec.lock listed no hosted packages.');
    return 2;
  }
  stdout.writeln('audit: querying OSV for ${packages.length} packages…');

  final List<List<String>> hits;
  try {
    hits = await _queryOsv(packages);
  } catch (error) {
    stderr.writeln('audit: OSV query failed: $error');
    if (allowNetworkFailure) {
      stderr.writeln('audit: continuing because --allow-network-failure.');
      return 0;
    }
    return 2;
  }

  bool blocked = false;
  for (int i = 0; i < hits.length; i++) {
    if (hits[i].isEmpty) continue;
    final String name = packages.keys.elementAt(i);
    final String version = packages[name]!;
    for (final String id in hits[i]) {
      final String severity = await _severityOf(id);
      final bool blocks = severityBlocksBuild(severity);
      blocked = blocked || blocks;
      stdout.writeln(
        '${blocks ? 'BLOCKING' : 'advisory'} $severity  '
        '$name $version  $id  https://osv.dev/vulnerability/$id',
      );
    }
  }

  if (blocked) {
    stderr.writeln(
      'audit: at least one HIGH/CRITICAL or unclassified advisory — failing.',
    );
    return 1;
  }
  stdout.writeln('audit: no HIGH/CRITICAL advisories.');
  return 0;
}

/// Name → version for every `hosted` package in the lockfile.
///
/// Deliberately a small line scanner rather than a YAML dependency: this runs
/// before `pub get` has necessarily produced anything, and adding a package to
/// audit the packages is its own kind of problem.
Map<String, String> _parseLockfile(List<String> lines) {
  final Map<String, String> packages = <String, String>{};
  String? current;
  bool inPackages = false;
  bool isHosted = false;

  for (final String line in lines) {
    if (line.startsWith('packages:')) {
      inPackages = true;
      continue;
    }
    if (!inPackages) continue;
    // A new top-level key ends the packages block.
    if (line.isNotEmpty && !line.startsWith(' ')) break;

    final RegExpMatch? name = RegExp(r'^  ([A-Za-z0-9_]+):$').firstMatch(line);
    if (name != null) {
      current = name.group(1);
      isHosted = false;
      continue;
    }
    if (current == null) continue;
    if (line.trim() == 'source: hosted') {
      isHosted = true;
      continue;
    }
    final RegExpMatch? version = RegExp(
      r'^    version: "?([^"]+)"?$',
    ).firstMatch(line);
    if (version != null && isHosted) {
      packages[current] = version.group(1)!;
      current = null;
    }
  }
  return packages;
}

/// One batch query for the whole lockfile. Returns the advisory ids per
/// package, in the order the packages were given.
Future<List<List<String>>> _queryOsv(Map<String, String> packages) async {
  final Map<String, Object?> body = <String, Object?>{
    'queries': <Map<String, Object?>>[
      for (final MapEntry<String, String> entry in packages.entries)
        <String, Object?>{
          'package': <String, String>{'name': entry.key, 'ecosystem': 'Pub'},
          'version': entry.value,
        },
    ],
  };

  final Map<String, Object?> decoded = await _postJson(_osvBatchUrl, body);
  final Object? results = decoded['results'];
  if (results is! List) {
    throw const FormatException('OSV response had no "results" list');
  }
  return <List<String>>[
    for (final Object? result in results)
      <String>[
        if (result is Map && result['vulns'] is List)
          for (final Object? vuln in result['vulns'] as List)
            if (vuln is Map && vuln['id'] is String) vuln['id'] as String,
      ],
  ];
}

/// The severity OSV assigns to [id], or `UNKNOWN`.
Future<String> _severityOf(String id) async {
  try {
    final Map<String, Object?> vuln = await _getJson('$_osvVulnUrl/$id');
    final Object? specific = vuln['database_specific'];
    if (specific is Map && specific['severity'] is String) {
      return (specific['severity'] as String).toUpperCase();
    }
    // OSV's generic `severity.score` can be a full CVSS vector rather than a
    // numeric score. This tool does not implement its own CVSS calculator;
    // returning UNKNOWN makes the caller fail closed instead of silently
    // accepting a potentially high advisory.
    return 'UNKNOWN';
  } catch (_) {
    return 'UNKNOWN';
  }
}

Future<Map<String, Object?>> _postJson(String url, Object? body) async {
  final HttpClient client = HttpClient();
  try {
    final HttpClientRequest request = await client.postUrl(Uri.parse(url));
    request.headers.contentType = ContentType.json;
    request.write(jsonEncode(body));
    final HttpClientResponse response = await request.close();
    // Awaited inside the try: the client must not be closed before the body
    // has been read.
    return await _decode(url, response);
  } finally {
    client.close();
  }
}

Future<Map<String, Object?>> _getJson(String url) async {
  final HttpClient client = HttpClient();
  try {
    final HttpClientResponse response = await (await client.getUrl(
      Uri.parse(url),
    )).close();
    return await _decode(url, response);
  } finally {
    client.close();
  }
}

Future<Map<String, Object?>> _decode(
  String url,
  HttpClientResponse response,
) async {
  final String text = await response.transform(utf8.decoder).join();
  if (response.statusCode != 200) {
    throw HttpException('$url answered ${response.statusCode}');
  }
  final Object? decoded = jsonDecode(text);
  if (decoded is! Map<String, Object?>) {
    throw FormatException('$url did not answer with an object');
  }
  return decoded;
}
