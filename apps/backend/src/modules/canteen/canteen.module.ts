import { Module } from '@nestjs/common';
import { CanteenController } from './canteen.controller';
import { CanteenService } from './canteen.service';
import { CanteenSyncService } from './canteen-sync.service';
import { MeineMensaClient } from './meine-mensa.client';

@Module({
  controllers: [CanteenController],
  providers: [CanteenService, CanteenSyncService, MeineMensaClient],
  exports: [CanteenService, CanteenSyncService],
})
export class CanteenModule {}
