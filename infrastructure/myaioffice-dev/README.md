# Campus Köthen DEV deployment — myaioffice.de

This directory is the versioned contract for the manually operated DEV stack.
GitHub Actions builds and scans immutable images; it never connects to the
server and never deploys them.

## Topology

| Item              | Value                                           |
| ----------------- | ----------------------------------------------- |
| Host              | `myaioffice.de`, Linux `amd64`                  |
| Server directory  | `/home/nexa/docker/campus-koethen-dev`          |
| CMS proxy         | `cms-dev.myaioffice.de` → `127.0.0.1:3020`      |
| API proxy         | `api-dev.myaioffice.de` → `127.0.0.1:3021`      |
| PostgreSQL        | private Compose service, no published host port |
| CMS database/role | `campus_cms_dev` / `campus_cms`                 |
| App database/role | `campus_app_dev` / `campus_app`                 |

CMS, API and worker run as the unprivileged `node` user. CMS and API bind to
host loopback only; PostgreSQL stays on the private Compose network. The worker
uses the backend image with `node dist/worker.js` and exposes no HTTP service.

## Images

GitHub Actions publishes both monorepo artefacts after all gates pass on `main`:

```text
ghcr.io/leviora-studio/campus-koethen/cms:sha-<full-commit-sha>
ghcr.io/leviora-studio/campus-koethen/backend:sha-<full-commit-sha>
```

Deploy the same immutable SHA for CMS and backend. Never deploy the moving
`main`/`dev` tags when reproducibility or rollback matters.

The backend image must contain both committed Prisma migrations and the
`node_modules/.bin/prisma` CLI. Its Docker build asserts this contract before
the image can be published.

## First start

```bash
cd /home/nexa/docker/campus-koethen-dev
cp .env.example .env
chmod 600 .env
$EDITOR .env

# Start the database and CMS first.
docker compose up -d db cms
```

Then:

1. Create the first Strapi Super-Admin manually.
2. Create the server-side read-only API token.
3. Put the token into `.env` as `STRAPI_API_TOKEN`.
4. Confirm that unauthenticated Strapi content requests are rejected.
5. Start API and worker with `docker compose up -d api worker`.

There is no seeded account or default password. `SEED_DEMO_CONTENT` remains
off on the shared DEV instance.

## Normal rollout

Wait until CI, image build, provenance and the blocking image scan are green.
Use the full SHA of that commit below.

```bash
cd /home/nexa/docker/campus-koethen-dev

# 1. Local rollback safety copy. This is not an offsite backup.
./scripts/backup-local.sh

# 2. Set both tags to the same immutable commit.
$EDITOR .env

# 3. Validate without printing resolved secrets, then fetch the images.
docker compose config --quiet
docker compose pull cms api worker migrate

# 4. Keep old application processes away from schema changes.
docker compose stop api worker

# 5. Apply committed app-database migrations from the new backend image.
docker compose --profile migrate run --rm migrate

# 6. Replace CMS first and wait for it to become healthy.
docker compose up -d cms
docker compose ps cms

# 7. Replace API and worker.
docker compose up -d api worker

# 8. Verify containers, databases and public health endpoints.
./scripts/verify.sh
docker compose logs --since=10m --tail=200 cms api worker
```

No `docker rm` is required. Compose recreates a service when its immutable image
tag changes.

### Room catalogue after the campus-map feature

The CMS room catalogue is an explicit, idempotent editorial-data sync. Run its
dry-run first and only apply after reviewing the plan:

```bash
docker compose exec cms node dist/scripts/rooms-sync.js --dry-run
docker compose exec cms node dist/scripts/rooms-sync.js
```

The path is `dist/scripts/`, not `scripts/`: the image ships the COMPILED
script, and `scripts/rooms-sync.ts` would need TypeScript tooling that a
production image deliberately does not carry.

The dry run prints a `create / update / unchanged / deactivate` plan and writes
nothing. A first run reports 30 creates; every later run reports 30 unchanged.
Editorial fields, room visibility and contact relations are never touched, and a
room that disappeared from the catalogue is deactivated rather than deleted.

The image build asserts this contract — `dist/scripts/rooms-sync.js` exists,
`@campus/map` resolves at runtime, and the canonical catalogue loads with its 30
demo rooms — so a published image that cannot run the sync fails the build
instead. Never install tooling interactively in the running container.

## Verification

Expected results:

- CMS `/_health`: HTTP 204
- API `/health/live`: HTTP 200
- API `/health/ready`: HTTP 200 with database and Strapi ready
- CMS and API: `healthy`
- worker: `Up` without an HTTP healthcheck
- PostgreSQL: private and `healthy`

`/health/live` deliberately checks only the API process. Dependency readiness
belongs to `/health/ready`; otherwise a database outage could cause a restart
loop.

## Rollback

Set `CMS_IMAGE_TAG` and `BACKEND_IMAGE_TAG` back to the previous immutable SHA,
then pull and recreate the services:

```bash
docker compose pull cms api worker
docker compose stop api worker
docker compose up -d cms
docker compose up -d api worker
./scripts/verify.sh
```

An image rollback does not undo a database migration. Migrations should follow
an expand/contract strategy. A destructive migration needs its own tested
rollback or a deliberate backup restore that accounts for data written since
the rollout.

## Backups

`scripts/backup-local.sh` creates mode-0600 local safety copies of:

- `campus_cms_dev`
- `campus_app_dev`
- the Strapi `uploads` directory

It retains these local copies for 14 days. This is useful before a rollout but
is **not** an offsite backup, does not protect against server loss, and has not
closed the release gate. A real backup solution needs remote storage,
monitoring and regular restore tests.

## Explicit boundaries

- no automatic deployment or SSH from CI
- no server secrets in the repository
- no public PostgreSQL port
- no moving image tags for reproducible rollouts
- no claim that local dumps are a complete backup system
- no DNS, Nginx or certificate mutation from this repository
