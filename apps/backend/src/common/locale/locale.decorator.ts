import { ExecutionContext, createParamDecorator } from '@nestjs/common';
import type { Request } from 'express';
import { ApiError } from '../errors/api-error';
import { LocaleResolution, UnsupportedLocaleError, resolveLocale } from './locale';

/**
 * Resolves the request locale per the documented contract and hands the
 * controller both what was asked for and what is actually being served.
 *
 * An explicitly unsupported `?locale=` becomes a 400 here, so no controller has
 * to remember the rule.
 */
export const RequestLocale = createParamDecorator(
  (_data: unknown, ctx: ExecutionContext): LocaleResolution => {
    const request = ctx.switchToHttp().getRequest<Request>();
    const queryLocale = request.query?.['locale'];

    try {
      return resolveLocale({
        queryLocale: typeof queryLocale === 'string' ? queryLocale : undefined,
        acceptLanguage: request.headers['accept-language'],
      });
    } catch (error) {
      if (error instanceof UnsupportedLocaleError) {
        throw new ApiError('UNSUPPORTED_LOCALE');
      }
      throw error;
    }
  },
);
