import { Controller, Get, Param, Query } from '@nestjs/common';
import { ApiOkResponse, ApiOperation, ApiQuery, ApiTags } from '@nestjs/swagger';
import { z } from 'zod';
import { ApiResponse, buildMeta } from '../../common/dto/meta.dto';
import { ApiError } from '../../common/errors/api-error';
import { LocaleResolution } from '../../common/locale/locale';
import { RequestLocale } from '../../common/locale/locale.decorator';
import { parseWith } from '../../common/validation/query';
import { RoomsService } from './rooms.service';
import { RoomDto, RoomResponseDto, RoomsResponseDto } from './rooms.types';

const KEY_PATTERN = /^[a-z0-9]+(?:-[a-z0-9]+)*$/;

const filterSchema = z.object({
  buildingKey: z.string().regex(KEY_PATTERN).max(120).optional(),
  floorKey: z.string().regex(KEY_PATTERN).max(120).optional(),
});

@ApiTags('rooms')
@Controller({ path: 'rooms', version: '1' })
export class RoomsController {
  constructor(private readonly rooms: RoomsService) {}

  @Get()
  @ApiOperation({
    summary: 'The public room catalogue for the bundled campus maps.',
    description:
      'Small and complete on purpose: the client caches it and searches locally, so there is no ' +
      'server-side full-text search. Only catalogue-active AND editorially visible rooms are served.',
  })
  @ApiQuery({ name: 'buildingKey', required: false })
  @ApiQuery({ name: 'floorKey', required: false })
  @ApiQuery({ name: 'locale', required: false, enum: ['de', 'en'] })
  @ApiOkResponse({ type: RoomsResponseDto })
  async list(
    @RequestLocale() locale: LocaleResolution,
    @Query() query: Record<string, unknown>,
  ): Promise<ApiResponse<RoomDto[]>> {
    const filters = parseWith(filterSchema, query, locale.resolvedLocale);
    const { data, translationFallback } = await this.rooms.listRooms(locale, filters);
    return { data, meta: buildMeta({ ...locale, translationFallback }) };
  }

  @Get(':roomKey')
  @ApiOperation({ summary: 'One room of the bundled campus maps.' })
  @ApiQuery({ name: 'locale', required: false, enum: ['de', 'en'] })
  @ApiOkResponse({ type: RoomResponseDto })
  async detail(
    @RequestLocale() locale: LocaleResolution,
    @Param('roomKey') roomKey: string,
  ): Promise<ApiResponse<RoomDto>> {
    if (!KEY_PATTERN.test(roomKey)) {
      throw new ApiError('ROOM_NOT_FOUND', locale.resolvedLocale);
    }
    const { data, translationFallback } = await this.rooms.getRoom(locale, roomKey);
    return { data, meta: buildMeta({ ...locale, translationFallback }) };
  }
}
