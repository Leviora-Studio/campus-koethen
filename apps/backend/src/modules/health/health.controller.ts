import { Controller, Get, Res } from '@nestjs/common';
import { ApiOkResponse, ApiOperation, ApiTags } from '@nestjs/swagger';
import type { Response } from 'express';
import { PrismaService } from '../../prisma/prisma.service';
import { StrapiClient } from '../strapi/strapi.client';

const READINESS_CHECK_TIMEOUT_MS = 3_000;

interface CheckResult {
  status: 'ok' | 'error' | 'not_configured';
  latencyMs?: number;
}

/** Bounds any check so a hanging dependency cannot hang the probe itself. */
async function timed(check: () => Promise<void>, timeoutMs: number): Promise<CheckResult> {
  const startedAt = Date.now();
  let timer: NodeJS.Timeout | undefined;
  try {
    await Promise.race([
      check(),
      new Promise<never>((_, reject) => {
        timer = setTimeout(() => reject(new Error('health check timed out')), timeoutMs);
      }),
    ]);
    return { status: 'ok', latencyMs: Date.now() - startedAt };
  } catch {
    return { status: 'error', latencyMs: Date.now() - startedAt };
  } finally {
    if (timer) clearTimeout(timer);
  }
}

@ApiTags('health')
@Controller('health')
export class HealthController {
  constructor(
    private readonly prisma: PrismaService,
    private readonly strapi: StrapiClient,
  ) {}

  /**
   * Liveness: is the process itself running?
   *
   * Deliberately checks NO dependency. If this failed on a database outage the
   * orchestrator would restart healthy containers and turn a recoverable
   * incident into a restart loop.
   */
  @Get('live')
  @ApiOperation({ summary: 'Liveness probe — process only, never a dependency.' })
  @ApiOkResponse({ schema: { example: { status: 'ok', uptimeSeconds: 1234 } } })
  live(): { status: 'ok'; uptimeSeconds: number } {
    return { status: 'ok', uptimeSeconds: Math.floor(process.uptime()) };
  }

  /**
   * Readiness: can this instance actually serve requests?
   *
   * The database is required. Strapi is reported but treated as non-fatal when
   * no token is configured yet, which is the honest state during initial setup
   * rather than a hidden failure.
   */
  @Get('ready')
  @ApiOperation({ summary: 'Readiness probe — bounded database and CMS checks.' })
  async ready(@Res({ passthrough: true }) res: Response): Promise<{
    status: 'ok' | 'degraded';
    checks: Record<string, CheckResult>;
  }> {
    const [database, strapi] = await Promise.all([
      timed(() => this.prisma.ping(), READINESS_CHECK_TIMEOUT_MS),
      this.strapi.isConfigured
        ? timed(() => this.strapi.probe(READINESS_CHECK_TIMEOUT_MS), READINESS_CHECK_TIMEOUT_MS)
        : Promise.resolve<CheckResult>({ status: 'not_configured' }),
    ]);

    const ready = database.status === 'ok' && strapi.status !== 'error';
    res.status(ready ? 200 : 503);

    return {
      status: ready ? 'ok' : 'degraded',
      checks: { database, strapi },
    };
  }
}
