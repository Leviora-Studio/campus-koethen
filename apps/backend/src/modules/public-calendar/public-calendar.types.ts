import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { ResponseMetaDto } from '../../common/dto/meta.dto';
import { LocationDto } from '../locations/locations.types';

/**
 * A fully-validated public-calendar definition, as mirrored from Strapi into
 * the operational read-model. `googleCalendarId` is server-internal and is
 * NEVER placed on a DTO.
 */
export interface CalendarDefinition {
  slug: string;
  googleCalendarId: string;
  /** Independent calendars can also be embedded on websites. */
  channelSlug: string | null;
  nameDe: string;
  nameEn: string | null;
  /** The channel's colour; a calendar has none of its own. */
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
  @ApiProperty({ description: 'The channel this calendar belongs to.' }) channelSlug!: string;
  @ApiProperty() name!: string;
  @ApiProperty({ example: '#5B3FD0', description: "The colour of the calendar's channel." })
  colorHex!: string;
  @ApiProperty() sortOrder!: number;
  @ApiProperty() defaultSubscribed!: boolean;
  @ApiProperty({ description: 'ready | stale', example: 'ready' }) dataState!: string;
  @ApiPropertyOptional({ nullable: true, type: String, format: 'date-time' })
  lastSuccessfulSyncAt!: string | null;
  @ApiProperty() dataStale!: boolean;
  @ApiProperty({ description: 'Safe HTTPS link to open this calendar in Google Calendar.' })
  googleOpenUrl!: string;
  @ApiProperty({
    type: LocationDto,
    nullable: true,
    description:
      "Campus location of the calendar, or null while none (or an inactive one) is set. Always the same as its channel's.",
  })
  location!: LocationDto | null;
}

export class CalendarLinkDto {
  @ApiProperty() label!: string;
  @ApiProperty() url!: string;
}
export class CalendarAttachmentDto {
  @ApiProperty() url!: string;
  @ApiProperty() name!: string;
  @ApiProperty() mimeType!: string;
}
export class PublicCalendarEventDto {
  @ApiPropertyOptional({ enum: ['editorial', 'post', 'google'] }) source?:
    'editorial' | 'post' | 'google';
  @ApiPropertyOptional({ nullable: true, type: String }) timeZone?: string | null;
  @ApiPropertyOptional({ nullable: true, type: String }) imageUrl?: string | null;
  @ApiPropertyOptional({ type: [CalendarLinkDto] }) links?: CalendarLinkDto[];
  @ApiPropertyOptional({ type: [CalendarAttachmentDto] }) attachments?: CalendarAttachmentDto[];
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
