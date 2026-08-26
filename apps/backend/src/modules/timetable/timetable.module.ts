import { Module } from '@nestjs/common';
import { TimetableController } from './timetable.controller';
import { TimetableService } from './timetable.service';
import { TimetableSyncService } from './timetable-sync.service';
import { WebUntisClient } from './webuntis.client';

@Module({
  controllers: [TimetableController],
  providers: [TimetableService, TimetableSyncService, WebUntisClient],
  exports: [TimetableService, TimetableSyncService],
})
export class TimetableModule {}
