// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import { ApiProperty } from '@nestjs/swagger';
import { ResponseMetaDto } from '../../common/dto/meta.dto';

/**
 * A campus location (Standort) as the public API names it. Strapi's
 * `documentId` and the editorial `isActive` flag stop at the mapper.
 */
export class LocationDto {
  @ApiProperty({ example: 'koethen', description: 'Stable, never localised.' })
  slug!: string;

  @ApiProperty({ example: 'Köthen', description: 'Place name, the same in every language.' })
  name!: string;
}

export class LocationsResponseDto {
  @ApiProperty({ type: [LocationDto] }) data!: LocationDto[];
  @ApiProperty({ type: ResponseMetaDto }) meta!: ResponseMetaDto;
}
