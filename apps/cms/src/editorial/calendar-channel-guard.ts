// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import type { Core } from '@strapi/strapi';
import { errors } from '@strapi/utils';

import {
  CHANNEL_UID,
  GuardContext,
  PUBLIC_CALENDAR_UID,
  extractRelationId,
  toRelationItems,
} from './post-guard';

/** A document on the other side of the channel ↔ calendar relation. */
export interface LinkedDocument {
  documentId: string;
  name: string | null;
}

/**
 * Reads the current assignment. A reference is whatever the relation payload
 * named: a `documentId`, or a numeric row id.
 */
export interface CalendarChannelLookup {
  calendarOfChannel(channel: string | number): Promise<LinkedDocument | null>;
  channelOfCalendar(calendar: string | number): Promise<LinkedDocument | null>;
}

/**
 * One public calendar per channel, and one channel per calendar.
 *
 * The app shows a calendar's events under its channel and in the channel's
 * colour, so a second calendar on the same channel has nowhere to go. Strapi's
 * own one-to-one relation would quietly move the link away from the calendar
 * that held it; this guard refuses the write instead and names the existing
 * assignment, so the editor decides which one stays.
 */
export function createCalendarChannelGuard(lookup: CalendarChannelLookup) {
  return async function calendarChannelGuard<T>(
    context: GuardContext,
    next: () => Promise<T>,
  ): Promise<T> {
    const data = context.params.data;
    if (
      (context.action === 'create' || context.action === 'update') &&
      data &&
      typeof data === 'object' &&
      !Array.isArray(data)
    ) {
      const record = data as Record<string, unknown>;
      const self = context.params.documentId;

      if (context.uid === PUBLIC_CALENDAR_UID) {
        for (const channel of relationRefs(record['channel'])) {
          const taken = await lookup.calendarOfChannel(channel);
          if (taken && taken.documentId !== self) {
            throw new errors.ValidationError(
              `This channel already has the public calendar "${taken.name ?? taken.documentId}". ` +
                'A channel can have only one calendar: remove it there first.',
            );
          }
        }
      }

      if (context.uid === CHANNEL_UID) {
        for (const calendar of relationRefs(record['publicCalendar'])) {
          const taken = await lookup.channelOfCalendar(calendar);
          if (taken && taken.documentId !== self) {
            throw new errors.ValidationError(
              `This public calendar already belongs to the channel "${taken.name ?? taken.documentId}". ` +
                'A calendar can belong to only one channel: remove it there first.',
            );
          }
        }
      }
    }

    return next();
  };
}

/** The documents a relation payload connects; a disconnect names none. */
function relationRefs(value: unknown): Array<string | number> {
  return toRelationItems(value)
    .map(extractRelationId)
    .filter((ref): ref is string | number => ref !== null);
}

/** Reads the assignment through Strapi's document service. */
export function strapiCalendarChannelLookup(strapi: Core.Strapi): CalendarChannelLookup {
  async function documentIdOf(uid: string, ref: string | number): Promise<string | null> {
    if (typeof ref === 'string') return ref;
    const row = (await strapi.db
      .query(uid as never)
      .findOne({ where: { id: ref }, select: ['documentId'] })) as { documentId?: string } | null;
    return row?.documentId ?? null;
  }

  async function linked(
    uid: typeof CHANNEL_UID | typeof PUBLIC_CALENDAR_UID,
    ref: string | number,
    field: 'publicCalendar' | 'channel',
  ): Promise<LinkedDocument | null> {
    const documentId = await documentIdOf(uid, ref);
    if (!documentId) return null;
    const found = (await strapi.documents(uid).findOne({
      documentId,
      populate: { [field]: { fields: ['name'] } },
    } as never)) as Record<string, unknown> | null;
    const other = found?.[field] as { documentId?: string; name?: string } | null | undefined;
    if (!other?.documentId) return null;
    return { documentId: other.documentId, name: other.name ?? null };
  }

  return {
    calendarOfChannel: (channel) => linked(CHANNEL_UID, channel, 'publicCalendar'),
    channelOfCalendar: (calendar) => linked(PUBLIC_CALENDAR_UID, calendar, 'channel'),
  };
}
