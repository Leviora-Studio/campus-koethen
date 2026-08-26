// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

/**
 * Argument parsing for `rooms:sync`.
 *
 * Lives beside the sync logic rather than inside the CLI entry point so it can
 * be tested without booting Strapi — importing the entry point would run it.
 */

export interface SyncOptions {
  dryRun: boolean;
}

export function parseSyncArgs(argv: readonly string[]): SyncOptions {
  // `pnpm run x -- --dry-run` forwards the bare separator as well; it carries
  // no meaning here and must not be mistaken for an unknown option.
  const flags = new Set(argv.slice(2).filter((arg) => arg !== '--'));
  for (const flag of flags) {
    if (flag !== '--dry-run') {
      throw new Error(`Unknown option "${flag}". Supported: --dry-run`);
    }
  }
  return { dryRun: flags.has('--dry-run') };
}
