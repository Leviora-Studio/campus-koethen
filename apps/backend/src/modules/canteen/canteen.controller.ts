import { Controller, Get, Param, Query } from '@nestjs/common';
import { ApiOkResponse, ApiOperation, ApiQuery, ApiTags } from '@nestjs/swagger';
import { ApiResponse, buildMeta } from '../../common/dto/meta.dto';
import { LocaleResolution } from '../../common/locale/locale';
import { RequestLocale } from '../../common/locale/locale.decorator';
import { dateRangeSchema, parseWith } from '../../common/validation/query';
import { CanteenService } from './canteen.service';
import {
  CanteenListItemDto,
  CanteenMenuDto,
  CanteenMenuResponseDto,
  CanteensResponseDto,
} from './canteen.types';

@ApiTags('canteens')
@Controller({ path: 'canteens', version: '1' })
export class CanteenController {
  constructor(private readonly canteens: CanteenService) {}

  @Get()
  @ApiOperation({
    summary: 'List active canteens.',
    description:
      'The upstream location_id is backend-only and never exposed. Adding a canteen therefore needs no app release.',
  })
  @ApiQuery({ name: 'locale', required: false, enum: ['de', 'en'] })
  @ApiOkResponse({
    description: 'Active canteens with their freshness metadata.',
    type: CanteensResponseDto,
  })
  async list(
    @RequestLocale() locale: LocaleResolution,
  ): Promise<ApiResponse<CanteenListItemDto[]>> {
    const data = await this.canteens.listCanteens(locale);
    // Canteen display names are API-owned and exist in both locales, so nothing
    // falls back here.
    return { data, meta: buildMeta({ ...locale, translationFallback: false }) };
  }

  @Get(':slug/menu')
  @ApiOperation({
    summary: 'Fetch the menu of one canteen for a date range.',
    description:
      'Every day in the range is returned, so an empty day is distinguishable from a loading error. Dish text is the original German from the source and is never machine-translated.',
  })
  @ApiQuery({ name: 'from', required: false, description: 'YYYY-MM-DD, defaults to today.' })
  @ApiQuery({ name: 'to', required: false, description: 'YYYY-MM-DD, at most 31 days after from.' })
  @ApiQuery({ name: 'locale', required: false, enum: ['de', 'en'] })
  @ApiOkResponse({ type: CanteenMenuResponseDto })
  async menu(
    @RequestLocale() locale: LocaleResolution,
    @Param('slug') slug: string,
    @Query() query: Record<string, unknown>,
  ): Promise<ApiResponse<CanteenMenuDto>> {
    const range = parseWith(dateRangeSchema, query, locale.resolvedLocale);
    const result = await this.canteens.getMenu(locale, slug, range);

    return {
      data: result.menu,
      meta: buildMeta({
        ...locale,
        // Dish text is always German. Serving English still means the meal text
        // itself is a fallback, and we say so rather than implying a translation.
        translationFallback: locale.resolvedLocale !== 'de',
        lastSuccessfulSyncAt: result.lastSuccessfulSyncAt,
        dataStale: result.dataStale,
        from: range.from,
        to: range.to,
      }),
    };
  }
}
