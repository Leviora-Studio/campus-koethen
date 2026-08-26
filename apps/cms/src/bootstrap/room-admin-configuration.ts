import type { Core } from '@strapi/strapi';

const ROOM_UID = 'api::room.room';
const ROOM_RELATION_UIDS = [
  'api::contact-area.contact-area',
  'api::contact-person.contact-person',
] as const;

type UnknownRecord = Record<string, unknown>;

interface ContentTypeConfigurationService {
  findContentType(uid: string): unknown;
  findConfiguration(contentType: unknown): Promise<UnknownRecord>;
  updateConfiguration(contentType: unknown, configuration: UnknownRecord): Promise<unknown>;
}

function record(value: unknown): UnknownRecord {
  return value && typeof value === 'object' && !Array.isArray(value)
    ? (value as UnknownRecord)
    : {};
}

/**
 * Strapi persists Content Manager layouts in the database. Updating the schema
 * order therefore changes the default only for new installations. This patch
 * keeps every existing layout option and changes just the fields responsible
 * for displaying rooms.
 */
export function roomAdminConfiguration(
  uid: string,
  configuration: UnknownRecord,
): { configuration: UnknownRecord; changed: boolean } {
  if (uid === ROOM_UID) {
    const settings = record(configuration.settings);
    if (settings.mainField === 'editorLabel') return { configuration, changed: false };
    return {
      configuration: {
        ...configuration,
        settings: { ...settings, mainField: 'editorLabel' },
      },
      changed: true,
    };
  }

  if (!ROOM_RELATION_UIDS.includes(uid as (typeof ROOM_RELATION_UIDS)[number])) {
    return { configuration, changed: false };
  }

  const metadatas = record(configuration.metadatas);
  const rooms = record(metadatas.rooms);
  const edit = record(rooms.edit);
  if (edit.mainField === 'editorLabel') return { configuration, changed: false };

  return {
    configuration: {
      ...configuration,
      metadatas: {
        ...metadatas,
        rooms: {
          ...rooms,
          edit: { ...edit, mainField: 'editorLabel' },
        },
      },
    },
    changed: true,
  };
}

export async function ensureRoomAdminConfiguration(strapi: Core.Strapi): Promise<void> {
  const service = strapi
    .plugin('content-manager')
    .service('content-types') as unknown as ContentTypeConfigurationService;

  for (const uid of [ROOM_UID, ...ROOM_RELATION_UIDS]) {
    const contentType = service.findContentType(uid);
    if (!contentType) throw new Error(`Content type ${uid} is unavailable`);

    const current = await service.findConfiguration(contentType);
    const next = roomAdminConfiguration(uid, current);
    if (next.changed) await service.updateConfiguration(contentType, next.configuration);
  }
}
