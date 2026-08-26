/**
 * LOCAL-ONLY sample content for manual testing.
 *
 * Creates a handful of demo news and event posts, in German and English,
 * attached to the channels/tags the bootstrap seed already creates. Every
 * title carries a visible "[Demo]" marker so this
 * content can never be mistaken for a real editorial post (AGENTS.md §5).
 *
 * This deliberately lives OUTSIDE src/bootstrap/seed.ts: that seed's own
 * comment states posts are never auto-generated there, because editorial
 * content is meant to be written by the editorial team. This script is an
 * explicit, human-triggered, local-only convenience — not part of the
 * bootstrap or CI.
 *
 * Usage:
 *   pnpm --filter @campus/cms sample:posts
 */

import { createStrapi } from '@strapi/strapi';

const POST_UID = 'api::post.post';

type Localised<T> = { de: T; en: T };

interface PostSeed {
  slug: string;
  tagSlug: 'news' | 'event';
  channelSlugs: string[];
  eventStart?: string;
  eventEnd?: string;
  eventAllDay?: boolean;
  title: Localised<string>;
  content: Localised<string>;
}

/** Allows the demo writer only in an explicitly local/test process. */
export function assertSamplePostsMayRun(nodeEnv = process.env.NODE_ENV): void {
  if (nodeEnv !== 'development' && nodeEnv !== 'test') {
    throw new Error('Refusing to seed sample posts outside development or test.');
  }
}

const POSTS: PostSeed[] = [
  {
    slug: 'demo-mensa-neue-oeffnungszeiten',
    tagSlug: 'news',
    channelSlugs: ['campus-news'],
    title: {
      de: '[Demo] Mensa testet neue Öffnungszeiten',
      en: '[Demo] Canteen trials new opening hours',
    },
    content: {
      de: 'Dies ist ein Demo-Beitrag ohne redaktionellen Anspruch, angelegt zu Testzwecken in der lokalen Entwicklungsumgebung. Er dient ausschließlich dazu, die News-Ansicht der App mit Beispieldaten zu befüllen.',
      en: 'This is a demo post without editorial claim, created for testing purposes in the local development environment. It exists solely to populate the app’s news view with sample data.',
    },
  },
  {
    slug: 'demo-neue-fahrradstellplaetze',
    tagSlug: 'news',
    channelSlugs: ['campus-news'],
    title: {
      de: '[Demo] Neue überdachte Fahrradstellplätze am Hauptgebäude',
      en: '[Demo] New covered bike racks at the main building',
    },
    content: {
      de: 'Dies ist ein Demo-Beitrag ohne redaktionellen Anspruch, angelegt zu Testzwecken in der lokalen Entwicklungsumgebung.',
      en: 'This is a demo post without editorial claim, created for testing purposes in the local development environment.',
    },
  },
  {
    slug: 'demo-fb5-projektpraesentationen',
    tagSlug: 'news',
    channelSlugs: ['fb5-news'],
    title: {
      de: '[Demo] FB5: Projektpräsentationen im Wintersemester',
      en: '[Demo] FB5: Project presentations this winter term',
    },
    content: {
      de: 'Dies ist ein Demo-Beitrag ohne redaktionellen Anspruch, angelegt zu Testzwecken in der lokalen Entwicklungsumgebung.',
      en: 'This is a demo post without editorial claim, created for testing purposes in the local development environment.',
    },
  },
  {
    slug: 'demo-erstiwoche-campusrallye',
    tagSlug: 'event',
    channelSlugs: ['campus-news'],
    eventStart: '2026-10-05T09:00:00.000Z',
    eventEnd: '2026-10-05T13:00:00.000Z',
    eventAllDay: false,
    title: {
      de: '[Demo] Erstiwoche: Campusrallye',
      en: '[Demo] Freshers’ week: campus rally',
    },
    content: {
      de: 'Dies ist ein Demo-Event ohne redaktionellen Anspruch, angelegt zu Testzwecken in der lokalen Entwicklungsumgebung.',
      en: 'This is a demo event without editorial claim, created for testing purposes in the local development environment.',
    },
  },
  {
    slug: 'demo-stura-vollversammlung',
    tagSlug: 'event',
    channelSlugs: ['campus-news'],
    eventStart: '2026-11-12T17:00:00.000Z',
    eventEnd: '2026-11-12T19:00:00.000Z',
    eventAllDay: false,
    title: {
      de: '[Demo] Vollversammlung des Studierendenrats',
      en: '[Demo] Student council general assembly',
    },
    content: {
      de: 'Dies ist ein Demo-Event ohne redaktionellen Anspruch, angelegt zu Testzwecken in der lokalen Entwicklungsumgebung.',
      en: 'This is a demo event without editorial claim, created for testing purposes in the local development environment.',
    },
  },
  {
    slug: 'demo-fb5-langer-abend-der-studienberatung',
    tagSlug: 'event',
    channelSlugs: ['fb5-news'],
    eventStart: '2026-11-20T00:00:00.000Z',
    eventEnd: '2026-11-20T23:59:00.000Z',
    eventAllDay: true,
    title: {
      de: '[Demo] FB5: Langer Abend der Studienberatung',
      en: '[Demo] FB5: Late-night study advice evening',
    },
    content: {
      de: 'Dies ist ein Demo-Event ohne redaktionellen Anspruch, angelegt zu Testzwecken in der lokalen Entwicklungsumgebung.',
      en: 'This is a demo event without editorial claim, created for testing purposes in the local development environment.',
    },
  },
];

function toBlocks(text: string): unknown[] {
  return [{ type: 'paragraph', children: [{ type: 'text', text }] }];
}

interface DocumentService {
  findMany(params: Record<string, unknown>): Promise<Record<string, unknown>[]>;
  create(params: Record<string, unknown>): Promise<unknown>;
  update(params: Record<string, unknown>): Promise<unknown>;
}

async function main(): Promise<void> {
  assertSamplePostsMayRun();
  const app = await createStrapi({ appDir: process.cwd(), distDir: 'dist' }).load();

  try {
    const posts = app.documents(POST_UID) as unknown as DocumentService;

    const tags = app.documents('api::tag.tag') as unknown as DocumentService;
    const channels = app.documents('api::channel.channel') as unknown as DocumentService;

    async function resolveDocumentId(service: DocumentService, slug: string): Promise<string> {
      const found = await service.findMany({
        filters: { slug: { $eq: slug } },
        locale: 'de',
        status: 'published',
        limit: 1,
      });
      if (found.length === 0) {
        throw new Error(`Could not resolve slug "${slug}" — run the bootstrap seed first.`);
      }
      return found[0]['documentId'] as string;
    }

    let created = 0;
    let updated = 0;

    for (const post of POSTS) {
      const existing = await posts.findMany({
        filters: { slug: { $eq: post.slug } },
        locale: 'de',
        limit: 1,
      });

      const tagDocumentId = await resolveDocumentId(tags, post.tagSlug);
      const channelDocumentIds = await Promise.all(
        post.channelSlugs.map((slug) => resolveDocumentId(channels, slug)),
      );

      // NOTE: bare relation identifiers ({documentId}), not the {connect:[...]}
      // wrapper. The editorial guard (src/editorial/post-guard.ts,
      // ensurePrimaryChannelInChannels) merges primaryChannel into channels by
      // pushing the raw value it was given; fed a {connect:[...]} wrapper it
      // nests that wrapper inside the channels array and relation resolution
      // then fails with "Invalid relations". Bare identifiers are exactly the
      // shape that helper already expects and produces.
      const sharedData: Record<string, unknown> = {
        slug: post.slug,
        tag: { documentId: tagDocumentId },
        primaryChannel: { documentId: channelDocumentIds[0] },
        channels: channelDocumentIds.map((documentId) => ({ documentId })),
        eventStart: post.eventStart ?? null,
        eventEnd: post.eventEnd ?? null,
        eventAllDay: post.eventAllDay ?? false,
      };

      const localisedDe = {
        title: post.title.de,
        content: toBlocks(post.content.de),
      };
      const localisedEn = {
        title: post.title.en,
        content: toBlocks(post.content.en),
      };

      // The editorial guard re-validates tag/primaryChannel on every publishing
      // write. For a brand-new locale, its own findOne(documentId, locale)
      // doesn't yet see the just-created 'de' entry, so the shared relation
      // fields have to travel with the 'en' write too, not just the text.
      if (existing.length === 0) {
        const doc = (await posts.create({
          data: { ...sharedData, ...localisedDe },
          locale: 'de',
          status: 'published',
        })) as { documentId: string };
        await posts.update({
          documentId: doc.documentId,
          data: { ...sharedData, ...localisedEn },
          locale: 'en',
          status: 'published',
        });
        created += 1;
      } else {
        const documentId = existing[0]['documentId'] as string;
        await posts.update({
          documentId,
          data: { ...sharedData, ...localisedDe },
          locale: 'de',
          status: 'published',
        });
        await posts.update({
          documentId,
          data: { ...sharedData, ...localisedEn },
          locale: 'en',
          status: 'published',
        });
        updated += 1;
      }
    }

    process.stderr.write(
      `[sample:posts] done: ${created} created, ${updated} updated (de + en, idempotent)\n`,
    );
  } finally {
    await app.destroy();
  }

  process.exit(0);
}

if (require.main === module) {
  void main().catch((error: unknown) => {
    // One generic message only: raw Strapi/database errors can contain URLs,
    // query details or configuration values and do not belong in CI logs.
    void error;
    process.stderr.write('[sample:posts] failed; inspect the local CMS logs.\n');
    process.exit(1);
  });
}
