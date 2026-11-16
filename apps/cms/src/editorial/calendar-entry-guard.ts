import type { Core } from '@strapi/strapi';
import { errors } from '@strapi/utils';
import { GuardContext } from './post-guard';

export function validateCalendarEntry(data: Record<string, unknown>): void {
  const start = typeof data.start === 'string' ? Date.parse(data.start) : NaN;
  const end = typeof data.end === 'string' ? Date.parse(data.end) : NaN;
  if (!Number.isFinite(start) || !Number.isFinite(end) || end <= start) {
    throw new errors.ValidationError('End must be strictly after start.');
  }
  try {
    new Intl.DateTimeFormat('en', { timeZone: String(data.timeZone) });
  } catch {
    throw new errors.ValidationError('A valid IANA time zone is required.');
  }
  if (!data.timeZone) throw new errors.ValidationError('A time zone is required.');
  if (
    data.allDay &&
    [start, end].some((date) => !new Date(date).toISOString().endsWith('T00:00:00.000Z'))
  ) {
    throw new errors.ValidationError('All-day dates use UTC midnight; end is exclusive.');
  }
}

export function createCalendarEntryGuard(strapi: Core.Strapi) {
  return async <T>(context: GuardContext, next: () => Promise<T>): Promise<T> => {
    if (
      context.uid !== 'api::calendar-entry.calendar-entry' ||
      !['create', 'update', 'publish'].includes(context.action)
    )
      return next();
    const existing = context.params.documentId
      ? await strapi.documents('api::calendar-entry.calendar-entry').findOne({
          documentId: context.params.documentId,
          locale: context.params.locale,
        })
      : null;
    const patch =
      context.params.data && typeof context.params.data === 'object' ? context.params.data : {};
    validateCalendarEntry({ timeZone: 'Europe/Berlin', ...existing, ...patch });
    return next();
  };
}
