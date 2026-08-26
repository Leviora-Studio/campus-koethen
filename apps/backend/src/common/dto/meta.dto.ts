import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Locale } from '../locale/locale';

export class PaginationMetaDto {
  @ApiProperty({ example: 1 }) page!: number;
  @ApiProperty({ example: 20 }) pageSize!: number;
  @ApiProperty({ example: 42 }) total!: number;
  @ApiProperty({ example: 3 }) totalPages!: number;
}

export class ResponseMetaDto {
  @ApiProperty({ enum: ['de', 'en'], description: 'Locale the client asked for.' })
  requestedLocale!: Locale;

  @ApiProperty({ enum: ['de', 'en'], description: 'Locale actually served.' })
  resolvedLocale!: Locale;

  @ApiProperty({
    description:
      'True when at least one delivered field came from the German fallback although another locale was requested.',
  })
  translationFallback!: boolean;

  @ApiPropertyOptional({ type: PaginationMetaDto })
  pagination?: PaginationMetaDto;

  @ApiPropertyOptional({
    type: [String],
    description: 'Content block types removed because the MVP client does not render them.',
  })
  droppedBlockTypes?: string[];

  // --- Canteen-specific freshness metadata ---------------------------------

  @ApiPropertyOptional({
    type: String,
    format: 'date-time',
    nullable: true,
    description: 'Last successful canteen synchronisation. Null means: never succeeded.',
  })
  lastSuccessfulSyncAt?: string | null;

  @ApiPropertyOptional({
    description: 'True when the data is older than the configured threshold.',
  })
  dataStale?: boolean;

  @ApiPropertyOptional({ description: 'Start of the resolved date range (YYYY-MM-DD).' })
  from?: string;

  @ApiPropertyOptional({ description: 'End of the resolved date range (YYYY-MM-DD).' })
  to?: string;

  @ApiPropertyOptional({
    description:
      'True when the server hit its own result ceiling and deliberately cut the list short. ' +
      'The client must say so rather than present the result as complete.',
  })
  truncated?: boolean;

  // --- Timetable-specific metadata -----------------------------------------

  @ApiPropertyOptional({
    description: 'False when the timetable integration is switched off server-side.',
  })
  featureEnabled?: boolean;

  @ApiPropertyOptional({
    enum: ['ready', 'pending', 'unavailable'],
    description:
      'ready = data present; pending = enabled but not yet synchronised; unavailable = disabled or permanently without data.',
  })
  dataState?: 'ready' | 'pending' | 'unavailable';

  @ApiPropertyOptional({
    description: 'Business timezone the wall-clock times belong to.',
    example: 'Europe/Berlin',
  })
  timezone?: string;
}

/** Envelope shared by every content endpoint — see docs/api.md §1. */
export interface ApiResponse<T> {
  data: T;
  meta: ResponseMetaDto;
}

export function buildMeta(input: {
  requestedLocale: Locale;
  resolvedLocale: Locale;
  translationFallback?: boolean;
  pagination?: PaginationMetaDto;
  droppedBlockTypes?: string[];
  lastSuccessfulSyncAt?: string | null;
  dataStale?: boolean;
  from?: string;
  to?: string;
  truncated?: boolean;
  featureEnabled?: boolean;
  dataState?: 'ready' | 'pending' | 'unavailable';
  timezone?: string;
}): ResponseMetaDto {
  const meta: ResponseMetaDto = {
    requestedLocale: input.requestedLocale,
    resolvedLocale: input.resolvedLocale,
    translationFallback: input.translationFallback ?? false,
  };
  if (input.pagination) {
    meta.pagination = input.pagination;
  }
  if (input.droppedBlockTypes && input.droppedBlockTypes.length > 0) {
    meta.droppedBlockTypes = input.droppedBlockTypes;
  }
  if (input.lastSuccessfulSyncAt !== undefined) {
    meta.lastSuccessfulSyncAt = input.lastSuccessfulSyncAt;
  }
  if (input.dataStale !== undefined) {
    meta.dataStale = input.dataStale;
  }
  if (input.from !== undefined) {
    meta.from = input.from;
  }
  if (input.to !== undefined) {
    meta.to = input.to;
  }
  if (input.truncated !== undefined) {
    meta.truncated = input.truncated;
  }
  if (input.featureEnabled !== undefined) {
    meta.featureEnabled = input.featureEnabled;
  }
  if (input.dataState !== undefined) {
    meta.dataState = input.dataState;
  }
  if (input.timezone !== undefined) {
    meta.timezone = input.timezone;
  }
  return meta;
}
