import { ApiProperty } from '@nestjs/swagger';
import { ResponseMetaDto } from '../../common/dto/meta.dto';

export class UserTestEnvironmentDto {
  @ApiProperty({
    description:
      'True when this deployment may contain synthetic user-test content. Clients must disclose that state globally.',
  })
  userTestData!: boolean;
}

export class UserTestEnvironmentResponseDto {
  @ApiProperty({ type: UserTestEnvironmentDto }) data!: UserTestEnvironmentDto;
  @ApiProperty({ type: ResponseMetaDto }) meta!: ResponseMetaDto;
}
