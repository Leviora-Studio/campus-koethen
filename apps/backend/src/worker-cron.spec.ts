import { createWorkerCronJob } from './worker-cron';

describe('createWorkerCronJob', () => {
  it('configures the requested IANA timezone explicitly', () => {
    const job = createWorkerCronJob('0 3,15 * * *', 'Europe/Berlin', jest.fn());

    expect(job.cronTime.timeZone).toBe('Europe/Berlin');
  });

  it('supports the UTC fallback supplied by the environment config', () => {
    const job = createWorkerCronJob('*/10 * * * *', 'UTC', jest.fn());

    expect(job.cronTime.timeZone).toBe('UTC');
  });
});
