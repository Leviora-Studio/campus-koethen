// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import type { Core } from '@strapi/strapi';
import { errors } from '@strapi/utils';

import {
  CHANNEL_UID,
  GuardContext,
  LOCATION_UID,
  PUBLIC_CALENDAR_UID,
  extractRelationId,
  toRelationItems,
} from './post-guard';

type LinkedUid = typeof CHANNEL_UID | typeof PUBLIC_CALENDAR_UID;

/** A location as the guard names it in its messages. */
export interface LocationRef {
  documentId: string;
  name: string | null;
}

/** One side of a channel ↔ calendar pair. */
export interface PairSide {
  documentId: string;
  name: string | null;
  location: LocationRef | null;
}

/** A channel or calendar together with the calendar or channel it is linked to. */
export interface LinkedState extends PairSide {
  partner: PairSide | null;
}

/**
 * Reads the draft state, which is what editors change and what a later
 * publication copies. A reference is whatever a relation payload named: a
 * `documentId`, or a numeric row id.
 */
export interface ChannelLocationLookup {
  transaction?<T>(work: () => Promise<T>): Promise<T>;
  state(uid: LinkedUid, ref: string | number): Promise<LinkedState | null>;
  location(ref: string | number): Promise<LocationRef | null>;
}

/** What a write does to a to-one relation. */
type RelationChange =
  { kind: 'unchanged' } | { kind: 'cleared' } | { kind: 'set'; ref: string | number };

const UNCHANGED: RelationChange = { kind: 'unchanged' };
const CLEARED: RelationChange = { kind: 'cleared' };

/**
 * A channel and its public calendar belong to the same location.
 *
 *  - Linking a calendar to a channel needs both to name the same location
 *    already (or in the same write). Missing or different locations refuse
 *    the link with a message that says what to set first.
 *  - A linked channel or calendar cannot move to a location other than the one
 *    its partner names. A partner without location does not block: that is how
 *    pairs from before locations existed get theirs, one side after the other.
 *  - The same applies when channels or calendars are assigned from the
 *    location's own edit view.
 *
 * Removing a location, unlinking, and every write that touches neither the
 * location nor the link pass unchanged, so pairs without location stay
 * editable until an editor assigns one.
 */
export function createChannelLocationGuard(lookup: ChannelLocationLookup) {
  return async function channelLocationGuard<T>(
    context: GuardContext,
    next: () => Promise<T>,
  ): Promise<T> {
    const data = context.params.data;
    const relevant =
      [CHANNEL_UID, PUBLIC_CALENDAR_UID, LOCATION_UID].includes(context.uid) &&
      ['create', 'update'].includes(context.action) &&
      !!data &&
      typeof data === 'object' &&
      !Array.isArray(data);
    if (!relevant) return next();
    const record = data as Record<string, unknown>;

    const run = async () => {
      if (context.uid === LOCATION_UID) {
        await checkLocationWrite(lookup, context.params.documentId ?? null, record);
      } else {
        await checkLinkedWrite(lookup, context.uid as LinkedUid, context.params.documentId, record);
      }
      return next();
    };
    return lookup.transaction ? lookup.transaction(run) : run();
  };
}

async function checkLinkedWrite(
  lookup: ChannelLocationLookup,
  uid: LinkedUid,
  documentId: string | undefined,
  record: Record<string, unknown>,
): Promise<void> {
  const partnerUid: LinkedUid = uid === CHANNEL_UID ? PUBLIC_CALENDAR_UID : CHANNEL_UID;
  const locationChange = relationChange(record['location']);
  const partnerChange = relationChange(record[uid === CHANNEL_UID ? 'publicCalendar' : 'channel']);
  if (locationChange.kind === 'unchanged' && partnerChange.kind === 'unchanged') return;

  const current = documentId ? await lookup.state(uid, documentId) : null;
  const location =
    locationChange.kind === 'unchanged'
      ? (current?.location ?? null)
      : locationChange.kind === 'cleared'
        ? null
        : await lookup.location(locationChange.ref);

  let partner: PairSide | null;
  let newLink = false;
  if (partnerChange.kind === 'unchanged') {
    partner = current?.partner ?? null;
  } else if (partnerChange.kind === 'cleared') {
    partner = null;
  } else {
    partner = await lookup.state(partnerUid, partnerChange.ref);
    newLink = !!partner && partner.documentId !== current?.partner?.documentId;
  }
  if (!partner) return;

  const self: PairSide = {
    documentId: documentId ?? '',
    name: typeof record['name'] === 'string' ? record['name'] : (current?.name ?? null),
    location,
  };
  const [channel, calendar] = uid === CHANNEL_UID ? [self, partner] : [partner, self];

  if (newLink) {
    if (!channel.location || !calendar.location) throw missingLocation(channel, calendar);
    if (channel.location.documentId !== calendar.location.documentId) {
      throw differentLocations(channel, calendar, false);
    }
  } else if (
    channel.location &&
    calendar.location &&
    channel.location.documentId !== calendar.location.documentId
  ) {
    throw differentLocations(channel, calendar, true);
  }
}

async function checkLocationWrite(
  lookup: ChannelLocationLookup,
  self: string | null,
  record: Record<string, unknown>,
): Promise<void> {
  const attached: Record<LinkedUid, Array<string | number>> = {
    [CHANNEL_UID]: connectedRefs(record['channels']),
    [PUBLIC_CALENDAR_UID]: connectedRefs(record['calendars']),
  };
  if (!attached[CHANNEL_UID].length && !attached[PUBLIC_CALENDAR_UID].length) return;

  const states: Record<LinkedUid, LinkedState[]> = {
    [CHANNEL_UID]: [],
    [PUBLIC_CALENDAR_UID]: [],
  };
  for (const uid of [CHANNEL_UID, PUBLIC_CALENDAR_UID] as const) {
    for (const ref of attached[uid]) {
      const state = await lookup.state(uid, ref);
      if (state) states[uid].push(state);
    }
  }

  const name = typeof record['name'] === 'string' ? record['name'] : null;
  const target: LocationRef = self
    ? ((await lookup.location(self)) ?? { documentId: self, name })
    : { documentId: '', name };

  for (const uid of [CHANNEL_UID, PUBLIC_CALENDAR_UID] as const) {
    const partnerUid: LinkedUid = uid === CHANNEL_UID ? PUBLIC_CALENDAR_UID : CHANNEL_UID;
    const movingTogether = new Set(states[partnerUid].map((state) => state.documentId));
    for (const state of states[uid]) {
      const partner = state.partner;
      if (!partner?.location || partner.location.documentId === target.documentId) continue;
      if (movingTogether.has(partner.documentId)) continue;
      const moved: PairSide = { ...state, location: target };
      const [channel, calendar] = uid === CHANNEL_UID ? [moved, partner] : [partner, moved];
      throw differentLocations(channel, calendar, true);
    }
  }
}

/** Interprets a to-one relation payload in any shape Strapi accepts. */
function relationChange(value: unknown): RelationChange {
  if (value === undefined) return UNCHANGED;
  if (value === null) return CLEARED;
  if (Array.isArray(value)) return lastOf(value);
  if (typeof value === 'object') {
    const record = value as Record<string, unknown>;
    if ('set' in record || 'connect' in record || 'disconnect' in record) {
      if (Array.isArray(record['set'])) return lastOf(record['set']);
      const connect = Array.isArray(record['connect']) ? record['connect'] : [];
      if (connect.length) return lastOf(connect);
      const disconnect = Array.isArray(record['disconnect']) ? record['disconnect'] : [];
      return disconnect.length ? CLEARED : UNCHANGED;
    }
  }
  return lastOf([value]);
}

function lastOf(items: unknown[]): RelationChange {
  if (!items.length) return CLEARED;
  const ref = extractRelationId(items[items.length - 1]);
  return ref === null ? UNCHANGED : { kind: 'set', ref };
}

/** The documents a to-many relation payload connects; a disconnect names none. */
function connectedRefs(value: unknown): Array<string | number> {
  return toRelationItems(value)
    .map(extractRelationId)
    .filter((ref): ref is string | number => ref !== null);
}

function quoted(name: string | null, fallback: string): string {
  return `„${name ?? fallback}“`;
}

function locationLabel(location: LocationRef | null): string {
  return location ? `Standort ${quoted(location.name, location.documentId)}` : 'noch kein Standort';
}

function missingLocation(channel: PairSide, calendar: PairSide): errors.ValidationError {
  return new errors.ValidationError(
    `Kanal ${quoted(channel.name, 'ohne Namen')} und Kalender ${quoted(calendar.name, 'ohne Namen')} ` +
      'können erst verknüpft werden, wenn beide denselben Standort haben ' +
      `(Kanal: ${locationLabel(channel.location)}, Kalender: ${locationLabel(calendar.location)}). ` +
      'Bitte wähle zuerst für den Kanal und für den Kalender denselben Standort aus und verknüpfe sie danach.',
  );
}

function differentLocations(
  channel: PairSide,
  calendar: PairSide,
  linked: boolean,
): errors.ValidationError {
  const pair =
    `Kanal ${quoted(channel.name, 'ohne Namen')} (${locationLabel(channel.location)}) und ` +
    `Kalender ${quoted(calendar.name, 'ohne Namen')} (${locationLabel(calendar.location)})`;
  return new errors.ValidationError(
    linked
      ? `${pair} sind miteinander verknüpft und müssen denselben Standort haben. ` +
          'Wähle für beide denselben Standort – oder entferne zuerst die Verknüpfung zwischen Kanal und Kalender.'
      : `${pair} haben verschiedene Standorte. ` +
          'Ein Kanal kann nur mit einem Kalender desselben Standorts verknüpft werden.',
  );
}

/** Reads draft state through Strapi's document service. */
export function strapiChannelLocationLookup(strapi: Core.Strapi): ChannelLocationLookup {
  async function documentIdOf(uid: string, ref: string | number): Promise<string | null> {
    if (typeof ref === 'string') return ref;
    const row = (await strapi.db
      .query(uid as never)
      .findOne({ where: { id: ref }, select: ['documentId'] })) as { documentId?: string } | null;
    return row?.documentId ?? null;
  }

  function toLocation(value: unknown): LocationRef | null {
    const location = value as { documentId?: string; name?: string } | null | undefined;
    return location?.documentId
      ? { documentId: location.documentId, name: location.name ?? null }
      : null;
  }

  return {
    async transaction(work) {
      // Shares the calendar-channel guard's lock: two editors changing the two
      // sides of one pair at once must not both pass against the old state.
      return strapi.db.transaction(async ({ trx }) => {
        await trx.raw('SELECT pg_advisory_xact_lock(?)', [1_926_110_516]);
        return work();
      });
    },
    async state(uid, ref) {
      const documentId = await documentIdOf(uid, ref);
      if (!documentId) return null;
      const partnerField = uid === CHANNEL_UID ? 'publicCalendar' : 'channel';
      // The location and the link are not localised, so any locale's draft
      // carries them; a document may exist in only one of the locales.
      const [document] = (await strapi.documents(uid).findMany({
        filters: { documentId },
        locale: '*',
        status: 'draft',
        fields: ['name'],
        populate: {
          location: { fields: ['name'] },
          [partnerField]: { fields: ['name'], populate: { location: { fields: ['name'] } } },
        },
      } as never)) as unknown as Array<Record<string, unknown>>;
      if (!document) return null;
      const partner = document[partnerField] as
        { documentId?: string; name?: string; location?: unknown } | null | undefined;
      return {
        documentId,
        name: typeof document['name'] === 'string' ? document['name'] : null,
        location: toLocation(document['location']),
        partner: partner?.documentId
          ? {
              documentId: partner.documentId,
              name: partner.name ?? null,
              location: toLocation(partner.location),
            }
          : null,
      };
    },
    async location(ref) {
      const documentId = await documentIdOf(LOCATION_UID, ref);
      if (!documentId) return null;
      const location = await strapi
        .documents(LOCATION_UID as never)
        .findOne({ documentId, fields: ['name'] } as never);
      return toLocation(location ? { ...(location as object), documentId } : null);
    },
  };
}
