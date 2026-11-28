// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import {
  Body,
  Controller,
  Get,
  Header,
  Headers,
  HttpCode,
  Param,
  Put,
  Query,
} from '@nestjs/common';
import { ApiExcludeController } from '@nestjs/swagger';
import { z } from 'zod';
import { ApiError } from '../../common/errors/api-error';
import { parseWith } from '../../common/validation/query';
import { pollKeySchema } from './post-poll';
import { installationHash, PostEngagementService } from './post-engagement.service';

const installation = z.string().regex(/^[0-9a-f]{64}$/);
const slug = z
  .string()
  .max(100)
  .regex(/^[a-z0-9]+(?:-[a-z0-9]+)*$/);
const slugs = z
  .string()
  .max(5050)
  .transform((value) => [...new Set(value.split(','))])
  .pipe(z.array(slug).min(1).max(50));
const rgiEmoji = new RegExp('^\\p{RGI_Emoji}$', 'v');
const reaction = z.object({ emoji: z.string().max(64).regex(rgiEmoji).nullable() }).strict();
const vote = z.object({ pollKey: pollKeySchema, optionKey: pollKeySchema }).strict();

@ApiExcludeController()
@Controller({ path: 'app/post-engagement', version: '1' })
export class PostEngagementController {
  constructor(private readonly engagement: PostEngagementService) {}

  @Get()
  @Header('Cache-Control', 'private, no-store')
  async read(@Query('posts') posts: unknown, @Headers('x-campus-installation') token?: string) {
    const parsed = installation.safeParse(token);
    return {
      data: await this.engagement.read(
        parseWith(slugs, posts, 'de'),
        parsed.success ? installationHash(parsed.data) : undefined,
      ),
    };
  }

  @Put(':slug/reaction')
  @HttpCode(204)
  async react(
    @Param('slug') post: unknown,
    @Body() body: unknown,
    @Headers('x-campus-installation') token?: string,
    @Headers('origin') origin?: string,
  ) {
    const device = this.appInstallation(token, origin);
    await this.engagement.react(
      parseWith(slug, post, 'de'),
      device,
      parseWith(reaction, body, 'de').emoji,
    );
  }

  @Put(':slug/vote')
  @HttpCode(204)
  async vote(
    @Param('slug') post: unknown,
    @Body() body: unknown,
    @Headers('x-campus-installation') token?: string,
    @Headers('origin') origin?: string,
  ) {
    const device = this.appInstallation(token, origin);
    const input = parseWith(vote, body, 'de');
    await this.engagement.vote(parseWith(slug, post, 'de'), device, input.pollKey, input.optionKey);
  }

  private appInstallation(token: string | undefined, origin: string | undefined): string {
    if (origin !== undefined) throw new ApiError('VALIDATION_FAILED');
    return installationHash(parseWith(installation, token, 'de'));
  }
}
