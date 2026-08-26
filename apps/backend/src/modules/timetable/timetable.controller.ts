import { Controller, Get, Query } from '@nestjs/common';
import { ApiOkResponse, ApiOperation, ApiQuery, ApiTags } from '@nestjs/swagger';
import { z } from 'zod';
import { ApiResponse, buildMeta } from '../../common/dto/meta.dto';
import { LocaleResolution } from '../../common/locale/locale';
import { RequestLocale } from '../../common/locale/locale.decorator';
import { isoDate, parseWith, refineDateRange } from '../../common/validation/query';
import { TimetableService } from './timetable.service';
import { TIMETABLE_TIMEZONE } from './webuntis.schema';
import {
  TimetableGroupDto,
  TimetableGroupsResponseDto,
  TimetableStatusDto,
  TimetableStatusResponseDto,
  TimetableWeekDto,
  TimetableWeekResponseDto,
} from './timetable.types';

/** A timetable window is bounded; an unbounded range is an availability risk. */
const MAX_RANGE_DAYS = 42;

const groupsQuerySchema = z.object({
  query: z.string().trim().max(100).optional(),
  department: z.string().trim().max(100).optional(),
});

const weekQuerySchema = refineDateRange(
  z.object({ groupId: z.uuid('must be a Campus group id'), from: isoDate, to: isoDate }),
  MAX_RANGE_DAYS,
);

@ApiTags('timetable')
@Controller({ path: 'timetable', version: '1' })
export class TimetableController {
  constructor(private readonly timetable: TimetableService) {}

  @Get('groups')
  @ApiOperation({
    summary: 'List selectable class groups.',
    description:
      'Comes from the synchronised catalogue, never from a live upstream call. Identifiers are Campus UUIDs; the source system id is never exposed.',
  })
  @ApiQuery({
    name: 'query',
    required: false,
    description: 'Searches short name, long name and department.',
  })
  @ApiQuery({ name: 'department', required: false })
  @ApiQuery({ name: 'locale', required: false, enum: ['de', 'en'] })
  @ApiOkResponse({ type: TimetableGroupsResponseDto })
  async groups(
    @RequestLocale() locale: LocaleResolution,
    @Query() query: Record<string, unknown>,
  ): Promise<ApiResponse<TimetableGroupDto[]>> {
    const filter = parseWith(groupsQuerySchema, query, locale.resolvedLocale);
    const result = await this.timetable.listGroups(locale, filter);

    return {
      data: result.data,
      meta: buildMeta({
        ...locale,
        // Group names are the source's own strings and are never translated.
        translationFallback: locale.resolvedLocale !== 'de',
        featureEnabled: this.timetable.featureEnabled,
        lastSuccessfulSyncAt: result.lastSyncAt?.toISOString() ?? null,
        dataStale: result.stale,
      }),
    };
  }

  @Get('entries')
  @ApiOperation({
    summary: 'Fetch one group’s timetable for a date range.',
    description:
      'Every day of the range is returned, so a genuinely free day is distinguishable from a loading error. Range is capped at 42 days.',
  })
  @ApiQuery({ name: 'groupId', required: true, format: 'uuid' })
  @ApiQuery({ name: 'from', required: true, example: '2026-07-20' })
  @ApiQuery({ name: 'to', required: true, example: '2026-08-02' })
  @ApiQuery({ name: 'locale', required: false, enum: ['de', 'en'] })
  @ApiOkResponse({ type: TimetableWeekResponseDto })
  async entries(
    @RequestLocale() locale: LocaleResolution,
    @Query() query: Record<string, unknown>,
  ): Promise<ApiResponse<TimetableWeekDto>> {
    const range = parseWith(weekQuerySchema, query, locale.resolvedLocale);
    const result = await this.timetable.getWeek(locale, range.groupId, range);

    return {
      data: result.data,
      meta: buildMeta({
        ...locale,
        // Subjects, rooms and teachers stay in the source language.
        translationFallback: locale.resolvedLocale !== 'de',
        timezone: TIMETABLE_TIMEZONE,
        from: range.from,
        to: range.to,
        lastSuccessfulSyncAt: result.lastSyncAt?.toISOString() ?? null,
        dataStale: result.stale,
        dataState: result.dataState,
        featureEnabled: this.timetable.featureEnabled,
      }),
    };
  }

  @Get('status')
  @ApiOperation({
    summary: 'Public health of the timetable integration.',
    description: 'Deliberately thin: no upstream URLs, headers, external ids or error detail.',
  })
  @ApiQuery({ name: 'locale', required: false, enum: ['de', 'en'] })
  @ApiOkResponse({ type: TimetableStatusResponseDto })
  async status(
    @RequestLocale() locale: LocaleResolution,
  ): Promise<ApiResponse<TimetableStatusDto>> {
    return {
      data: await this.timetable.getStatus(),
      meta: buildMeta({ ...locale, translationFallback: false }),
    };
  }
}
