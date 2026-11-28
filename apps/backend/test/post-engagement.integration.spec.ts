import { randomBytes } from 'node:crypto';
import { PostEngagementController } from '../src/modules/posts/post-engagement.controller';
import {
  installationHash,
  PostEngagementService,
} from '../src/modules/posts/post-engagement.service';
import type { PostsService } from '../src/modules/posts/posts.service';
import type { PrismaService } from '../src/prisma/prisma.service';
import { createTestPrisma } from './helpers/database';

const post = 'demo-post-engagement';
const poll = {
  key: 'demo-poll',
  options: [{ key: 'first' }, { key: 'second' }],
};
const browser = 'https://example.test';

describe('post engagement with isolated PostgreSQL', () => {
  const prisma = createTestPrisma();
  const getPostBySlug = jest.fn(async () => ({ data: { poll } }));
  const app = new PostEngagementController(
    new PostEngagementService(
      prisma as PrismaService,
      { getPostBySlug } as unknown as PostsService,
    ),
  );

  beforeEach(async () => {
    await prisma.postReaction.deleteMany({ where: { postSlug: post } });
    await prisma.postPollVote.deleteMany({ where: { postSlug: post } });
  });
  afterAll(async () => {
    await prisma.$disconnect();
  });

  it('validates writes and counts one current reaction and vote per installation', async () => {
    const a = randomBytes(32).toString('hex');
    const b = randomBytes(32).toString('hex');

    await expect(app.react(post, { emoji: '👍' }, a, browser)).rejects.toThrow();
    await expect(app.react(post, { emoji: 'a' }, a)).rejects.toThrow();
    await expect(app.react(post, { emoji: '👍' })).rejects.toThrow();

    await Promise.all([
      app.react(post, { emoji: '👍' }, a),
      app.react(post, { emoji: '👍' }, a),
      app.react(post, { emoji: '🧑‍🎓' }, b),
      app.vote(post, { pollKey: poll.key, optionKey: 'first' }, a),
      app.vote(post, { pollKey: poll.key, optionKey: 'first' }, a),
    ]);
    await expect(app.vote(post, { pollKey: poll.key, optionKey: 'invalid' }, a)).rejects.toThrow();
    await app.vote(post, { pollKey: poll.key, optionKey: 'second' }, a);
    await app.react(post, { emoji: '🧑‍🎓' }, a);

    expect((await app.read(post, a)).data[post]).toEqual({
      reactions: [{ emoji: '🧑‍🎓', count: 2 }],
      myReaction: '🧑‍🎓',
      votes: [{ pollKey: poll.key, optionKey: 'second', count: 1 }],
      myVotes: [{ pollKey: poll.key, optionKey: 'second' }],
    });
    expect((await app.read(post)).data[post]?.myReaction).toBeNull();
    expect(await prisma.postReaction.count({ where: { installation: installationHash(a) } })).toBe(
      1,
    );

    await app.react(post, { emoji: null }, a);
    expect((await app.read(post, a)).data[post]?.reactions).toEqual([{ emoji: '🧑‍🎓', count: 1 }]);
  });
});
