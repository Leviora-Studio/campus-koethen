// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import { Module } from '@nestjs/common';
import { PostsController } from './posts.controller';
import { PostsService } from './posts.service';
import { PostEngagementController } from './post-engagement.controller';
import { PostEngagementService } from './post-engagement.service';

@Module({
  controllers: [PostsController, PostEngagementController],
  providers: [PostsService, PostEngagementService],
  exports: [PostsService],
})
export class PostsModule {}
