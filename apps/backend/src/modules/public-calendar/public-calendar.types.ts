import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { ResponseMetaDto } from '../../common/dto/meta.dto';

/**
 * A fully-validated public-calendar definition, as mirrored from Strapi into
 * the operational read-model. `googleCalendarId` is server-internal and is
 * NEVER placed on a DTO.
 */
export interface CalendarDefinition {
  slug: string;
  googleCalendarId: string;
  channelSlug: string | null;
  nameDe: string;
  nameEn: string | null;
  colorHex: string;
  sortOrder: number;
  defaultSubscribed: boolean;
  includeEventDescription: boolean;
  includeEventLocation: boolean;
}

// --- DTOs -------------------------------------------------------------------

export class PublicCalendarDto {
  @ApiProperty() id!: string;
  @ApiProperty() slug!: string;
  @ApiPropertyOptional({ nullable: true, type: String }) channelSlug!: string | null;
  @ApiProperty() name!: string;
  @ApiProperty({ example: '#5B3FD0' }) colorHex!: string;
  @ApiProperty() sortOrder!: number;
  @ApiProperty() defaultSubscribed!: boolean;
  @ApiProperty({ description: 'ready | stale', example: 'ready' }) dataState!: string;
  @ApiPropertyOptional({ nullable: true, type: String, format: 'date-time' })
  lastSuccessfulSyncAt!: string | null;
  @ApiProperty() dataStale!: boolean;
  @ApiProperty({ description: 'Safe HTTPS link to open this calendar in Google Calendar.' })
  googleOpenUrl!: string;
}

export class PublicCalendarEventDto {
  @ApiProperty({
    description:
      'Stable, non-invertible eventKey = base64url(sha256(calendarSlug + "\\0" + occurrenceKey))[0..21].',
  })
  id!: string;
  @ApiProperty() calendarId!: string;
  @ApiProperty() calendarSlug!: string;
  @ApiProperty() title!: string;
  @ApiPropertyOptional({ type: String, nullable: true }) description!: string | null;
  @ApiPropertyOptional({ type: String, nullable: true }) location!: string | null;
  @ApiProperty({ type: String, format: 'date-time' }) start!: string;
  @ApiProperty({ type: String, format: 'date-time' }) end!: string;
  @ApiProperty() allDay!: boolean;
  @ApiProperty({ description: 'confirmed | tentative | cancelled' }) status!: string;
}

export class PublicCalendarListResponseDto {
  @ApiProperty({ type: [PublicCalendarDto] }) data!: PublicCalendarDto[];
  @ApiProperty({ type: ResponseMetaDto }) meta!: ResponseMetaDto;
}

export class PublicCalendarEventsResponseDto {
  @ApiProperty({ type: [PublicCalendarEventDto] }) data!: PublicCalendarEventDto[];
  @ApiProperty({ type: ResponseMetaDto }) meta!: ResponseMetaDto;
}

export class GoogleViewUrlDataDto {
  @ApiProperty({ description: 'A calendar.google.com embed URL for the selected calendars.' })
  url!: string;
}

export class GoogleViewUrlResponseDto {
  @ApiProperty({ type: GoogleViewUrlDataDto }) data!: GoogleViewUrlDataDto;
  @ApiProperty({ type: ResponseMetaDto }) meta!: ResponseMetaDto;
}
