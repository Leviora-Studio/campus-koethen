// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import { AsyncLocalStorage } from 'node:async_hooks';

/**
 * Marks the narrow call path that is allowed to write catalogue-managed room
 * fields.
 *
 * This is deliberately NOT a global flag. A module-level boolean would be
 * switched on for the whole process and every concurrent request would inherit
 * it — exactly the "unsafe global bypass switch" this must not be. An
 * AsyncLocalStorage scope is bound to one asynchronous call tree: only code
 * that the sync itself invoked runs inside it, an admin-panel request never
 * does, and the scope disappears automatically when the sync returns.
 *
 * The AsyncLocalStorage INSTANCE is kept in the global symbol registry, which
 * is a different thing from a global flag: it carries no state of its own and
 * changes none of the semantics above. It is necessary because this file is
 * loaded twice in one process — Strapi boots the application from `dist/`
 * while `rooms:sync` imports the same sources through ts-node. With a
 * plain module-level instance each copy gets its own storage, the guard cannot
 * see the scope the sync opened, and it rejects exactly the writes it is meant
 * to allow. That is not theoretical: it is what happened on the first run
 * against a real Strapi, and test/catalog-scope.test.ts pins it down.
 */

const REGISTRY_KEY = Symbol.for('dev.erikengler.campuskoethen.catalogSyncScope');

type ScopeRegistry = { [REGISTRY_KEY]?: AsyncLocalStorage<true> };

function scopeStorage(): AsyncLocalStorage<true> {
  const registry = globalThis as ScopeRegistry;
  const existing = registry[REGISTRY_KEY];
  if (existing) {
    return existing;
  }
  const created = new AsyncLocalStorage<true>();
  registry[REGISTRY_KEY] = created;
  return created;
}

/** Runs `fn` on the internal catalogue write path. */
export function runAsCatalogSync<T>(fn: () => Promise<T>): Promise<T> {
  return scopeStorage().run(true, fn);
}

/** True only inside {@link runAsCatalogSync}. */
export function isCatalogSync(): boolean {
  return scopeStorage().getStore() === true;
}
