/**
 * Safe coercions for values that arrive from outside the type system —
 * upstream JSON bodies and request query strings.
 *
 * `String(value)` on an `unknown` is a trap: an object silently becomes the
 * literal text "[object Object]", which would then be stored as a slug or
 * echoed back to a client as if it were real data. These helpers narrow first
 * and fall back explicitly instead.
 */

/** Returns the value only if it really is a string, otherwise the fallback. */
export function asString(value: unknown, fallback = ''): string {
  return typeof value === 'string' ? value : fallback;
}

/** Like {@link asString}, but treats an empty/whitespace-only string as absent. */
export function asNonEmptyString(value: unknown): string | null {
  return typeof value === 'string' && value.trim().length > 0 ? value : null;
}

/** Returns the value only if it is a finite number, otherwise the fallback. */
export function asNumber(value: unknown, fallback: number): number {
  return typeof value === 'number' && Number.isFinite(value) ? value : fallback;
}
