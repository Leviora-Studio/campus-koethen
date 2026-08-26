// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import 'grade.dart';

/// Encrypted local store for the last successful Notenspiegel and the sync
/// timestamps.
///
/// Implementations MUST be encrypted at rest (a random 256-bit key kept in the
/// keychain/keystore). The two timestamps are deliberately separate:
///  - [readLastAttemptedSync] gates the 24-hour automatic sync and is written on
///    every attempt, so a failed attempt is not retried on every rebuild.
///  - [readLastSuccessfulSync] is the "last updated" the user sees and is
///    written ONLY after a successful sync.
///
/// A failed or structurally invalid portal response must NEVER reach this store;
/// only a verified report is written, so the last good cache always survives.
abstract interface class GradeCacheStore {
  Future<GradeReport?> readReport();
  Future<void> writeReport(GradeReport report);

  Future<DateTime?> readLastSuccessfulSync();
  Future<void> writeLastSuccessfulSync(DateTime at);

  Future<DateTime?> readLastAttemptedSync();
  Future<void> writeLastAttemptedSync(DateTime at);

  /// Wipes report, timestamps AND the encryption key. Called on account removal.
  Future<void> clear();
}
