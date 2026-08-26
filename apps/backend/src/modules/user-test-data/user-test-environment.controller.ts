import { Controller, Get } from '@nestjs/common';
import { ApiOkResponse, ApiOperation, ApiQuery, ApiTags } from '@nestjs/swagger';
import { ApiResponse, buildMeta } from '../../common/dto/meta.dto';
import { LocaleResolution } from '../../common/locale/locale';
import { RequestLocale } from '../../common/locale/locale.decorator';
import { UserTestEnvironmentService } from './user-test-environment.service';
import {
  UserTestEnvironmentDto,
  UserTestEnvironmentResponseDto,
} from './user-test-environment.types';

@ApiTags('environment')
@Controller({ path: 'environment', version: '1' })
export class UserTestEnvironmentController {
  constructor(private readonly environment: UserTestEnvironmentService) {}

  @Get()
  @ApiOperation({ summary: 'Return public deployment disclosure flags.' })
  @ApiQuery({ name: 'locale', required: false, enum: ['de', 'en'] })
  @ApiOkResponse({ type: UserTestEnvironmentResponseDto })
  async get(
    @RequestLocale() locale: LocaleResolution,
  ): Promise<ApiResponse<UserTestEnvironmentDto>> {
    return {
      data: { userTestData: await this.environment.isActive() },
      meta: buildMeta({ ...locale, translationFallback: false }),
    };
  }
}
