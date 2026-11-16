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
    const uid = 'api::calendar-entry.calendar-entry';
    const locale = context.params.locale ?? 'de';
    const documentId = context.params.documentId;
    const patch =
      context.params.data && typeof context.params.data === 'object' ? context.params.data : {};
    if (locale === '*' || Array.isArray(locale)) {
      const drafts = await strapi
        .documents(uid)
        .findMany({ filters: { documentId }, locale, status: 'draft' });
      for (const draft of drafts) validateCalendarEntry({ ...draft, ...patch });
      return next();
    }
    let existing = documentId
      ? await strapi.documents(uid).findOne({ documentId, locale, status: 'draft' })
      : null;
    // Strapi creates a missing translation through update() and copies the shared
    // fields afterwards. Validate those fields from the canonical document first.
    if (!existing && documentId && locale !== 'de')
      existing = await strapi.documents(uid).findOne({ documentId, locale: 'de', status: 'draft' });
    validateCalendarEntry({ timeZone: 'Europe/Berlin', ...existing, ...patch });
    return next();
  };
}
