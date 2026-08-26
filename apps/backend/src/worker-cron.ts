import { CronJob } from 'cron';

/** Build a stopped cron job whose wall-clock schedule uses an explicit zone. */
export function createWorkerCronJob(
  cronTime: string,
  timeZone: string,
  onTick: () => void,
): CronJob {
  return CronJob.from({
    cronTime,
    onTick,
    start: false,
    timeZone,
  });
}
