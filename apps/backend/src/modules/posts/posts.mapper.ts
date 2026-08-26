// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import { sanitizeBlocks } from '../../common/content/content-blocks';
import {
  ChannelDto,
  ChannelRefDto,
  ImageDto,
  PostDetailDto,
  PostListItemDto,
  TagDto,
  TagRefDto,
} from './posts.types';
import { asString } from '../../common/util/coerce';
import { publicMediaUrl } from '../media/media.path';

/**
 * Strapi -> public DTO mapping for posts, channels, and tags.
 *
 * This is the single boundary where upstream structures are dropped. Every
 * field of the public contract is written out explicitly rather than spread
 * from the source object, so a new Strapi field can never leak by accident.
 */

type Raw = Record<string, unknown>;

function isRecord(value: unknown): value is Raw {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function str(value: unknown): string | null {
  return typeof value === 'string' && value.length > 0 ? value : null;
}

function num(value: unknown): number | null {
  return typeof value === 'number' && Number.isFinite(value) ? value : null;
}

/** Only https URLs are forwarded; anything else becomes null. */
function httpsUrl(value: unknown): string | null {
  if (typeof value !== 'string' || value.length === 0) {
    return null;
  }
  try {
    return new URL(value).protocol === 'https:' ? value : null;
  } catch {
    return null;
  }
}

function mapImage(value: unknown): ImageDto | null {
  if (!isRecord(value)) {
    return null;
  }
  // Served by this API rather than linked straight to Strapi: the app must not
  // talk to the CMS (AGENTS.md §2.1), and the local upload provider publishes
  // relative URLs that a mobile client cannot resolve at all.
  const url = publicMediaUrl(value['url']);
  if (!url) {
    return null;
  }
  return {
    url,
    alternativeText: str(value['alternativeText']),
    width: num(value['width']),
    height: num(value['height']),
  };
}

export function mapChannel(raw: Raw): ChannelDto {
  const publicCalendar = isRecord(raw['publicCalendar']) ? raw['publicCalendar'] : null;
  const publicCalendarSlug = publicCalendar ? str(publicCalendar['slug']) : null;

  return {
    slug: asString(raw['slug']),
    name: asString(raw['name']),
    description: str(raw['description']),
    colorHex: asString(raw['colorHex'], '#5B3FD0'),
    sortOrder: num(raw['sortOrder']) ?? 0,
    defaultSubscribed: raw['defaultSubscribed'] === true,
    publicCalendarSlug,
  };
}

export function mapChannelRef(raw: unknown): ChannelRefDto | null {
  if (!isRecord(raw)) {
    return null;
  }
  const slug = str(raw['slug']);
  if (!slug) {
    return null;
  }
  return {
    slug,
    name: asString(raw['name']),
    colorHex: asString(raw['colorHex'], '#5B3FD0'),
  };
}

export function mapTag(raw: Raw): TagDto {
  return {
    slug: asString(raw['slug']),
    name: asString(raw['name']),
  };
}

export function mapTagRef(raw: unknown): TagRefDto | null {
  if (!isRecord(raw)) {
    return null;
  }
  const slug = str(raw['slug']);
  if (!slug) {
    return null;
  }
  return {
    slug,
    name: asString(raw['name']),
  };
}

function mapList<T>(value: unknown, map: (entry: unknown) => T | null): T[] {
  if (!Array.isArray(value)) {
    return [];
  }
  return value.map(map).filter((entry): entry is T => entry !== null);
}

/**
 * Maps one post, content included.
 *
 * Content travels with the LIST entry, not only with the detail: the app's
 * feed renders each post inline, so fetching them one by one would be a
 * request per visible card. Sanitising happens here, once — unsanitised Strapi
 * blocks never reach a client.
 */
export function mapPostListItem(raw: Raw): {
  item: PostListItemDto | null;
  droppedBlockTypes: string[];
} {
  const { blocks, droppedBlockTypes } = sanitizeBlocks(raw['content']);

  const tagRef = mapTagRef(raw['tag']);
  const primaryChannelRef = mapChannelRef(raw['primaryChannel']);

  if (!tagRef || !primaryChannelRef) {
    return { item: null, droppedBlockTypes };
  }

  let channels = mapList(raw['channels'], mapChannelRef);
  if (channels.length === 0) {
    channels = [primaryChannelRef];
  } else if (!channels.some((c) => c.slug === primaryChannelRef.slug)) {
    channels = [primaryChannelRef, ...channels];
  }

  return {
    item: {
      slug: asString(raw['slug']),
      title: asString(raw['title']),
      publishedAt: str(raw['publishedAt']),
      heroImage: mapImage(raw['heroImage']),
      tag: tagRef,
      primaryChannel: primaryChannelRef,
      channels,
      sourceName: str(raw['sourceName']),
      sourceUrl: httpsUrl(raw['sourceUrl']),
      content: blocks,
      eventStart: str(raw['eventStart']),
      eventEnd: str(raw['eventEnd']),
      eventAllDay: raw['eventAllDay'] === true,
    },
    droppedBlockTypes,
  };
}

/**
 * The detail shape is the list shape.
 */
export function mapPostDetail(raw: Raw): {
  post: PostDetailDto | null;
  droppedBlockTypes: string[];
} {
  const { item, droppedBlockTypes } = mapPostListItem(raw);
  return { post: item, droppedBlockTypes };
}
