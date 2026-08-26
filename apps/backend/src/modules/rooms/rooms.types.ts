import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { ResponseMetaDto } from '../../common/dto/meta.dto';

/**
 * Public shapes for /v1/rooms*.
 *
 * The room catalogue contains the rooms of explicitly marked schematic
 * building plans. The DTO carries no Strapi internals: clients only ever see
 * the stable `roomKey`.
 */

export class RoomDto {
  @ApiProperty({ example: 'ratke-gebaeude-first-floor-216' }) roomKey!: string;
  @ApiProperty({ example: '216' }) roomNumber!: string;

  @ApiProperty({ example: 'ratke-gebaeude' }) buildingKey!: string;
  @ApiProperty({ example: '23', description: 'Stable campus building number.' })
  buildingNumber!: string;
  @ApiProperty({ description: 'Localised building name.' }) buildingName!: string;

  @ApiProperty({ example: 'ratke-gebaeude-first-floor' }) floorKey!: string;
  @ApiProperty({ description: 'Localised floor name.' }) floorName!: string;

  @ApiProperty({
    enum: ['room', 'lecture', 'seminar', 'office', 'lab', 'meeting', 'service'],
    description: 'Stable technical key; the client renders a localised label.',
  })
  roomType!: string;

  @ApiPropertyOptional({ type: String, nullable: true, description: 'Localised display name.' })
  displayName!: string | null;

  @ApiPropertyOptional({ type: String, nullable: true, description: 'Localised description.' })
  description!: string | null;

  @ApiProperty({
    example: 'campus-koethen-2026-08-26',
    description: 'Version of the map catalogue this room belongs to.',
  })
  mapVersion!: string;

  @ApiProperty() sortOrder!: number;
}

/**
 * A compact reference used by contact DTOs.
 *
 * Carries enough to render a readable line AND to deep-link into the campus
 * map, but never a Strapi id.
 */
export class RoomReferenceDto {
  @ApiProperty({ example: 'ratke-gebaeude-first-floor-216' }) roomKey!: string;
  @ApiProperty({ example: '216' }) roomNumber!: string;
  @ApiProperty({ example: '23', description: 'Stable campus building number.' })
  buildingNumber!: string;
  @ApiProperty({ description: 'Localised building name.' }) buildingName!: string;
  @ApiProperty({ description: 'Localised floor name.' }) floorName!: string;
  @ApiPropertyOptional({ type: String, nullable: true }) displayName!: string | null;
}

export class RoomsResponseDto {
  @ApiProperty({ type: [RoomDto] }) data!: RoomDto[];
  @ApiProperty({ type: ResponseMetaDto }) meta!: ResponseMetaDto;
}

export class RoomResponseDto {
  @ApiProperty({ type: RoomDto }) data!: RoomDto;
  @ApiProperty({ type: ResponseMetaDto }) meta!: ResponseMetaDto;
}
