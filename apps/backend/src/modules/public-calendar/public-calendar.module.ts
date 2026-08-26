import { Module } from '@nestjs/common';
import { ENV } from '../../config/app-config.module';
import { Env } from '../../config/env.schema';
import { GooglePublicIcsClient } from './google-public-ics.client';
import { PublicCalendarController } from './public-calendar.controller';
import { PublicCalendarService } from './public-calendar.service';
import { PublicCalendarSyncService } from './public-calendar-sync.service';

/**
 * Public calendars.
 *
 * The controller/service (read model) are used by the API; the sync service is
 * exported for the worker. `StrapiClient`, `PrismaService` and `ENV` come from
 * their @Global() modules.
 */
@Module({
  controllers: [PublicCalendarController],
  providers: [
    PublicCalendarService,
    PublicCalendarSyncService,
    {
      provide: GooglePublicIcsClient,
      useFactory: (env: Env) =>
        new GooglePublicIcsClient({
          timeoutMs: env.PUBLIC_CALENDAR_HTTP_TIMEOUT_MS,
          retryAttempts: env.PUBLIC_CALENDAR_RETRY_ATTEMPTS,
          requestSpacingMs: env.PUBLIC_CALENDAR_REQUEST_SPACING_MS,
          maxBytes: env.PUBLIC_CALENDAR_MAX_FEED_BYTES,
          userAgent: env.PUBLIC_CALENDAR_USER_AGENT,
        }),
      inject: [ENV],
    },
  ],
  exports: [PublicCalendarSyncService],
})
export class PublicCalendarModule {}
