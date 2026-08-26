import { Global, Module } from '@nestjs/common';
import { StrapiClient } from './strapi.client';

@Global()
@Module({
  providers: [StrapiClient],
  exports: [StrapiClient],
})
export class StrapiModule {}
