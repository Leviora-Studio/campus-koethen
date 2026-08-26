import { Module } from '@nestjs/common';
import { AppConfigModule } from './config/app-config.module';
import { PrismaModule } from './prisma/prisma.module';
import { CanteenModule } from './modules/canteen/canteen.module';
import { ContactsModule } from './modules/contacts/contacts.module';
import { HealthModule } from './modules/health/health.module';
import { PostsModule } from './modules/posts/posts.module';
import { PublicCalendarModule } from './modules/public-calendar/public-calendar.module';
import { MediaModule } from './modules/media/media.module';
import { RoomsModule } from './modules/rooms/rooms.module';
import { StrapiModule } from './modules/strapi/strapi.module';
import { TimetableModule } from './modules/timetable/timetable.module';
import { UserTestDataModule } from './modules/user-test-data/user-test-data.module';

/**
 * HTTP API composition.
 *
 * The scheduler is deliberately NOT registered here — synchronisation runs in
 * the separate worker entrypoint (src/worker.ts) so a slow or failing sync can
 * never block the API or cause it to restart.
 */
@Module({
  imports: [
    AppConfigModule,
    PrismaModule,
    StrapiModule,
    HealthModule,
    PostsModule,
    ContactsModule,
    CanteenModule,
    TimetableModule,
    PublicCalendarModule,
    RoomsModule,
    MediaModule,
    UserTestDataModule,
  ],
})
export class AppModule {}
