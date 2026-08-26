import { Module } from '@nestjs/common';
import { AppConfigModule } from './config/app-config.module';
import { PrismaModule } from './prisma/prisma.module';
import { CanteenModule } from './modules/canteen/canteen.module';
import { PublicCalendarModule } from './modules/public-calendar/public-calendar.module';
import { StrapiModule } from './modules/strapi/strapi.module';
import { TimetableModule } from './modules/timetable/timetable.module';
import { UserTestDataModule } from './modules/user-test-data/user-test-data.module';

/**
 * Composition for the worker process: configuration, database, and the sync
 * modules. It imports StrapiModule because the public-calendar catalogue sync
 * reads the published calendar DEFINITIONS from Strapi (public campus data) —
 * unlike the canteen/timetable sources. No HTTP layer is registered.
 */
@Module({
  imports: [
    AppConfigModule,
    PrismaModule,
    StrapiModule,
    CanteenModule,
    TimetableModule,
    PublicCalendarModule,
    UserTestDataModule,
  ],
})
export class WorkerModule {}
