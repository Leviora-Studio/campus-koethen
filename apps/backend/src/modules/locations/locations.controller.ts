// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import { Controller, Get } from '@nestjs/common';
import { ApiOkResponse, ApiOperation, ApiQuery, ApiTags } from '@nestjs/swagger';
import { ApiResponse, buildMeta } from '../../common/dto/meta.dto';
import { LocaleResolution } from '../../common/locale/locale';
import { RequestLocale } from '../../common/locale/locale.decorator';
import { LocationsService } from './locations.service';
import { LocationDto, LocationsResponseDto } from './locations.types';

@ApiTags('locations')
@Controller({ path: 'locations', version: '1' })
export class LocationsController {
  constructor(private readonly locations: LocationsService) {}

  @Get()
  @ApiOperation({
    summary: 'List active campus locations.',
    description:
      'The slugs accepted by the `location` filter of GET /v1/posts/channels, GET /v1/calendars ' +
      'and GET /v1/calendars/all. A location name is a place name and the same in every language.',
  })
  @ApiQuery({ name: 'locale', required: false, enum: ['de', 'en'] })
  @ApiOkResponse({ description: 'Active locations ordered by name.', type: LocationsResponseDto })
  async list(@RequestLocale() locale: LocaleResolution): Promise<ApiResponse<LocationDto[]>> {
    const data = await this.locations.list();
    return { data, meta: buildMeta({ ...locale, translationFallback: false }) };
  }
}
