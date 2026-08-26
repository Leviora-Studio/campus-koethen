// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import type { Core } from '@strapi/strapi';

export const POST_UID = 'api::post.post';
export const CHANNEL_UID = 'api::channel.channel';
export const TAG_UID = 'api::tag.tag';
export const PUBLIC_CALENDAR_UID = 'api::public-calendar.public-calendar';

export const RESERVED_POST_SLUGS = ['channels', 'tags', 'events'] as const;

export class EditorialValidationError extends Error {
  constructor(message: string) {
    super(message);
    this.name = 'EditorialValidationError';
  }
}

export interface GuardContext {
  uid: string;
  action: string;
  params: {
    documentId?: string;
    locale?: string;
    status?: string;
    data?: unknown;
    [key: string]: unknown;
  };
}

export function validatePostSlug(slug: unknown): void {
  if (typeof slug === 'string') {
    const normalized = slug.trim().toLowerCase();
    if ((RESERVED_POST_SLUGS as readonly string[]).includes(normalized)) {
      throw new EditorialValidationError(
        `The post slug "${slug}" is reserved and cannot be used. Reserved slugs: ${RESERVED_POST_SLUGS.join(', ')}`,
      );
    }
  }
}

export function validateEventDates(eventStart: unknown, eventEnd: unknown): void {
  if (
    eventStart !== undefined &&
    eventStart !== null &&
    eventEnd !== undefined &&
    eventEnd !== null
  ) {
    const start = new Date(eventStart as string).getTime();
    const end = new Date(eventEnd as string).getTime();
    if (!Number.isNaN(start) && !Number.isNaN(end) && end <= start) {
      throw new EditorialValidationError(
        `eventEnd (${eventEnd}) must be strictly after eventStart (${eventStart}).`,
      );
    }
  }
}

function extractRelationId(rel: unknown): string | number | null {
  if (typeof rel === 'string' || typeof rel === 'number') return rel;
  if (typeof rel === 'object' && rel !== null) {
    const rec = rel as Record<string, unknown>;
    if (typeof rec['documentId'] === 'string') return rec['documentId'];
    if (typeof rec['id'] === 'number' || typeof rec['id'] === 'string') return rec['id'];
    if (typeof rec['slug'] === 'string') return rec['slug'];
  }
  return null;
}

/**
 * Normalises any accepted relation input shape — a bare item, an array of
 * items, or a `{connect: [...]}` / `{set: [...]}` wrapper — into a flat array
 * of bare relation items ready to merge into another relation field.
 */
function toRelationItems(value: unknown): unknown[] {
  if (value === undefined || value === null) return [];
  if (Array.isArray(value)) return value;
  if (typeof value === 'object') {
    const rec = value as Record<string, unknown>;
    if (Array.isArray(rec['connect'])) return rec['connect'];
    if (Array.isArray(rec['set'])) return rec['set'];
  }
  return [value];
}

export function ensurePrimaryChannelInChannels(data: unknown): void {
  if (typeof data !== 'object' || data === null || Array.isArray(data)) return;
  const record = data as Record<string, unknown>;
  const primary = record['primaryChannel'];
  if (primary === undefined || primary === null) return;

  // primaryChannel may itself arrive as a bare item or a {connect/set: [...]}
  // wrapper. Merging the wrapper object itself (rather than the item(s) it
  // carries) into `channels` produces a malformed relation payload — that
  // was the root cause of "Invalid relations" write failures.
  const primaryItems = toRelationItems(primary);
  if (primaryItems.length === 0) return;

  const mergeInto = (target: unknown[]): void => {
    const existingIds = new Set(
      target.map(extractRelationId).filter((id): id is string | number => id !== null),
    );
    for (const item of primaryItems) {
      const id = extractRelationId(item);
      if (id !== null && existingIds.has(id)) continue;
      target.push(item);
      if (id !== null) existingIds.add(id);
    }
  };

  if (record['channels'] === undefined || record['channels'] === null) {
    record['channels'] = [...primaryItems];
    return;
  }

  if (Array.isArray(record['channels'])) {
    mergeInto(record['channels'] as unknown[]);
  } else if (typeof record['channels'] === 'object') {
    const channelsObj = record['channels'] as Record<string, unknown>;
    if (Array.isArray(channelsObj['connect'])) {
      mergeInto(channelsObj['connect'] as unknown[]);
    } else if (Array.isArray(channelsObj['set'])) {
      mergeInto(channelsObj['set'] as unknown[]);
    }
  }
}

export function validatePostPublishRequirements(
  doc: Record<string, unknown>,
  tagSlug?: string | null,
): void {
  validatePostSlug(doc['slug']);

  const tag = doc['tag'];
  if (tag === undefined || tag === null) {
    throw new EditorialValidationError('Cannot publish a post without a tag.');
  }

  const primaryChannel = doc['primaryChannel'];
  if (primaryChannel === undefined || primaryChannel === null) {
    throw new EditorialValidationError('Cannot publish a post without a primaryChannel.');
  }

  const isEventTag =
    tagSlug === 'event' ||
    (typeof tag === 'object' &&
      tag !== null &&
      (tag as Record<string, unknown>)['slug'] === 'event') ||
    (typeof tag === 'string' && tag === 'event');

  if (isEventTag) {
    const eventStart = doc['eventStart'];
    if (eventStart === undefined || eventStart === null || String(eventStart).trim() === '') {
      throw new EditorialValidationError(
        'Cannot publish an event post without a valid eventStart datetime.',
      );
    }
  }

  validateEventDates(doc['eventStart'], doc['eventEnd']);
}

export function createEditorialGuard(strapi?: Core.Strapi) {
  return async function editorialGuard<T>(
    context: GuardContext,
    next: () => Promise<T>,
  ): Promise<T> {
    if (context.uid === POST_UID) {
      const data = context.params.data;
      if (data && typeof data === 'object' && !Array.isArray(data)) {
        const record = data as Record<string, unknown>;
        if (record['slug'] !== undefined) {
          validatePostSlug(record['slug']);
        }
        ensurePrimaryChannelInChannels(record);
        validateEventDates(record['eventStart'], record['eventEnd']);
      }

      const isPublishing =
        context.action === 'publish' ||
        ((context.action === 'create' || context.action === 'update') &&
          context.params.status === 'published');

      if (isPublishing) {
        let existingDoc: Record<string, unknown> = {};
        if (context.params.documentId && strapi) {
          try {
            const found = await strapi.documents(POST_UID).findOne({
              documentId: context.params.documentId,
              locale: context.params.locale ?? 'de',
              populate: ['tag', 'primaryChannel', 'channels'],
            });
            if (found && typeof found === 'object') {
              existingDoc = found as Record<string, unknown>;
            }
          } catch {
            // fallback to data if findOne fails
          }
        }

        const merged = {
          ...existingDoc,
          ...(data && typeof data === 'object' && !Array.isArray(data)
            ? (data as Record<string, unknown>)
            : {}),
        };

        let tagSlug: string | null = null;
        if (merged['tag'] && typeof merged['tag'] === 'object') {
          tagSlug = ((merged['tag'] as Record<string, unknown>)['slug'] as string) ?? null;
        } else if (typeof merged['tag'] === 'string' && strapi) {
          try {
            const tagDoc = await strapi.documents(TAG_UID).findOne({
              documentId: merged['tag'] as string,
            });
            if (tagDoc && typeof tagDoc === 'object') {
              tagSlug = ((tagDoc as Record<string, unknown>)['slug'] as string) ?? null;
            }
          } catch {
            // ignore
          }
        }

        validatePostPublishRequirements(merged, tagSlug);
      }
    }

    return next();
  };
}
