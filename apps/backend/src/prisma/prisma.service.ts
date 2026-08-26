import { Inject, Injectable, Logger, OnModuleDestroy, OnModuleInit } from '@nestjs/common';
import { PrismaPg } from '@prisma/adapter-pg';
import { ENV } from '../config/app-config.module';
import { Env } from '../config/env.schema';
import { PrismaClient } from '../generated/prisma/client';

/**
 * Prisma 7 client.
 *
 * Prisma 7 no longer reads the connection URL from schema.prisma, so the client
 * is constructed with the pg driver adapter and the validated DATABASE_URL.
 *
 * This connects ONLY to the operational database (campus_app_<env>). Strapi's
 * database is a separate database with a separate role and is never reachable
 * from here — editorial content is read over Strapi's REST API instead.
 */
@Injectable()
export class PrismaService extends PrismaClient implements OnModuleInit, OnModuleDestroy {
  private readonly logger = new Logger(PrismaService.name);

  constructor(@Inject(ENV) env: Env) {
    super({ adapter: new PrismaPg({ connectionString: env.DATABASE_URL }) });
  }

  async onModuleInit(): Promise<void> {
    await this.$connect();
    this.logger.log('Connected to the operational database');
  }

  async onModuleDestroy(): Promise<void> {
    await this.$disconnect();
  }

  /**
   * Cheap liveness probe for the readiness endpoint. Bounded by the caller's
   * timeout so a hanging database cannot hang the health check.
   */
  async ping(): Promise<void> {
    await this.$queryRaw`SELECT 1`;
  }
}
