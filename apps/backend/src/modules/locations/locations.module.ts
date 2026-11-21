// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import { Module } from '@nestjs/common';
import { StrapiModule } from '../strapi/strapi.module';
import { LocationsController } from './locations.controller';
import { LocationsService } from './locations.service';

@Module({
  imports: [StrapiModule],
  controllers: [LocationsController],
  providers: [LocationsService],
})
export class LocationsModule {}
