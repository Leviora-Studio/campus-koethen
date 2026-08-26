// Prisma 7 configuration.
//
// The connection URL lives here (not in schema.prisma) and is used by the
// Prisma CLI for `migrate` and `db` commands. The runtime client uses the
// @prisma/adapter-pg driver adapter instead — see src/prisma/prisma.service.ts.
//
// DATABASE_URL is never hardcoded; it comes from the environment in every
// environment, including CI.

import 'dotenv/config';
import { defineConfig, env } from 'prisma/config';

export default defineConfig({
  schema: 'prisma/schema.prisma',
  migrations: {
    path: 'prisma/migrations',
  },
  datasource: {
    url: env('DATABASE_URL'),
    // Only `prisma migrate dev` uses a shadow database, and only during LOCAL
    // development: the application role is intentionally not a superuser and
    // cannot create databases, so infrastructure/local/initdb provisions one up
    // front. `prisma migrate deploy` — what actually runs on the server — never
    // touches it.
    //
    // Read conditionally rather than through env(), which throws when the
    // variable is absent. Requiring it everywhere would break `prisma generate`
    // in the Docker build and in CI, neither of which has a shadow database.
    ...(process.env['SHADOW_DATABASE_URL']
      ? { shadowDatabaseUrl: process.env['SHADOW_DATABASE_URL'] }
      : {}),
  },
});
