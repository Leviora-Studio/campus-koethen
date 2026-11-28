// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import { Injectable } from '@nestjs/common';
import { createHash } from 'node:crypto';
import { ApiError } from '../../common/errors/api-error';
import { PrismaService } from '../../prisma/prisma.service';
import { PostsService } from './posts.service';

export function installationHash(token: string): string {
  return createHash('sha256').update(token).digest('hex');
}

export interface Engagement {
  reactions: { emoji: string; count: number }[];
  votes: { pollKey: string; optionKey: string; count: number }[];
  myReaction: string | null;
  myVotes: { pollKey: string; optionKey: string }[];
}

const canonical = { requestedLocale: 'de', resolvedLocale: 'de' } as const;

@Injectable()
export class PostEngagementService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly posts: PostsService,
  ) {}

  async read(slugs: string[], installation: string | undefined) {
    const where = { postSlug: { in: slugs } };
    const reactionCounts = this.prisma.postReaction.groupBy({
      by: ['postSlug', 'emoji'],
      where,
      orderBy: { postSlug: 'asc' },
      _count: { _all: true },
    });
    const voteCounts = this.prisma.postPollVote.groupBy({
      by: ['postSlug', 'pollKey', 'optionKey'],
      where,
      orderBy: { postSlug: 'asc' },
      _count: { _all: true },
    });
    const [reactions, votes, myReactions, myVotes] = await this.prisma.$transaction(
      [
        reactionCounts,
        voteCounts,
        this.prisma.postReaction.findMany({
          where: { ...where, installation: installation ?? '' },
          select: { postSlug: true, emoji: true },
        }),
        this.prisma.postPollVote.findMany({
          where: { ...where, installation: installation ?? '' },
          select: { postSlug: true, pollKey: true, optionKey: true },
        }),
      ],
      { isolationLevel: 'RepeatableRead' },
    );

    const result = new Map<string, Engagement>(
      slugs.map((slug) => [slug, { reactions: [], votes: [], myReaction: null, myVotes: [] }]),
    );
    for (const row of reactions) {
      result.get(row.postSlug)?.reactions.push({ emoji: row.emoji, count: row._count._all });
    }
    for (const row of votes) {
      result.get(row.postSlug)?.votes.push({
        pollKey: row.pollKey,
        optionKey: row.optionKey,
        count: row._count._all,
      });
    }
    for (const row of myReactions) {
      const engagement = result.get(row.postSlug);
      if (engagement) engagement.myReaction = row.emoji;
    }
    for (const row of myVotes) {
      result.get(row.postSlug)?.myVotes.push({ pollKey: row.pollKey, optionKey: row.optionKey });
    }
    return Object.fromEntries(result);
  }

  async react(postSlug: string, installation: string, emoji: string | null) {
    await this.posts.getPostBySlug(canonical, postSlug);
    if (emoji === null) {
      await this.prisma.postReaction.deleteMany({ where: { postSlug, installation } });
      return;
    }

    await this.prisma.$executeRaw`
      INSERT INTO "post_reactions" ("postSlug", "installation", "emoji")
      VALUES (${postSlug}, ${installation}, ${emoji})
      ON CONFLICT ("postSlug", "installation") DO UPDATE SET "emoji" = EXCLUDED."emoji"
    `;
  }

  async vote(postSlug: string, installation: string, pollKey: string, optionKey: string) {
    const {
      data: { poll },
    } = await this.posts.getPostBySlug(canonical, postSlug);
    if (poll?.key !== pollKey || !poll.options.some((option) => option.key === optionKey)) {
      throw new ApiError('VALIDATION_FAILED');
    }
    await this.prisma.$executeRaw`
      INSERT INTO "post_poll_votes" ("postSlug", "pollKey", "installation", "optionKey")
      VALUES (${postSlug}, ${pollKey}, ${installation}, ${optionKey})
      ON CONFLICT ("postSlug", "pollKey", "installation")
      DO UPDATE SET "optionKey" = EXCLUDED."optionKey"
    `;
  }
}
