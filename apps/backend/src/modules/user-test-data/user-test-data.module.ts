import { Module } from '@nestjs/common';
import { CanteenModule } from '../canteen/canteen.module';
import { UserTestDataSeedService } from './user-test-data.seed.service';
import { UserTestEnvironmentController } from './user-test-environment.controller';
import { UserTestEnvironmentService } from './user-test-environment.service';

@Module({
  imports: [CanteenModule],
  controllers: [UserTestEnvironmentController],
  providers: [UserTestDataSeedService, UserTestEnvironmentService],
  exports: [UserTestDataSeedService],
})
export class UserTestDataModule {}
