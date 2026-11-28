// Campus Köthen App · AGPL-3.0-only
// Copyright © 2026 Leviora Studio and Jona Loreen Sommer

import { z } from 'zod';

export const pollKeySchema = z
  .string()
  .max(60)
  .regex(/^[a-z0-9]+(?:-[a-z0-9]+)*$/);
export const pollPopulate = { populate: { options: { fields: ['key', 'label'] } } };

const optionSchema = z.object({
  key: pollKeySchema,
  label: z.string().trim().min(1).max(180),
});
const pollSchema = z.object({
  key: pollKeySchema,
  question: z.string().trim().min(1).max(240),
  options: z
    .array(optionSchema)
    .min(2)
    .max(8)
    .refine((options) => new Set(options.map((option) => option.key)).size === options.length),
});

export function parsePostPoll(value: unknown) {
  const parsed = pollSchema.safeParse(value);
  return parsed.success ? parsed.data : null;
}

export function localizedPoll(canonical: unknown, localized: unknown) {
  const poll = parsePostPoll(canonical);
  const translation = parsePostPoll(localized);
  if (
    !poll ||
    translation?.key !== poll.key ||
    translation.options.length !== poll.options.length
  ) {
    return poll;
  }
  const options = new Map(translation.options.map((option) => [option.key, option]));
  if (!poll.options.every((option) => options.has(option.key))) return poll;
  return {
    ...poll,
    question: translation.question,
    options: poll.options.map((option) => options.get(option.key) ?? option),
  };
}
