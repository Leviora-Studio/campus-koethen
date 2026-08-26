import { Global, Module } from '@nestjs/common';
import { Env, validateEnv } from './env.schema';

/**
 * Validated configuration, resolved exactly once at boot.
 *
 * Nothing in the codebase reads `process.env` directly outside this module and
 * the logger, so a missing or malformed variable surfaces as a single clear
 * startup failure instead of an undefined value deep inside a request.
 */

export const ENV = Symbol('CAMPUS_ENV');

@Global()
@Module({
  providers: [
    {
      provide: ENV,
      useFactory: (): Env => validateEnv(process.env),
    },
  ],
  exports: [ENV],
})
export class AppConfigModule {}
