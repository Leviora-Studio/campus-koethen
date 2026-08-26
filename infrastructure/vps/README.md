# Portable VPS deployment

This directory is the source-checkout-free deployment contract for Campus
Koethen. The target server pulls immutable CMS and backend images from GitHub
Container Registry (`ghcr.io/leviora-studio/campus-koethen/...`);
it does not build images and does not need a clone of this repository.

GitHub Actions builds and scans the images after every CI gate passes on `main`
or a version tag. It publishes only images that pass the blocking Trivy scan;
deployments remain manual. See `docs/architecture.md` §7.1.

## Files needed on the VPS

Only two files are required at runtime:

```text
compose.yaml
.env
```

The database bootstrap is embedded in `compose.yaml`. PostgreSQL data and
Strapi uploads live in named Docker volumes. Nginx and TLS termination remain
outside Docker and forward to the loopback ports configured in `.env`.

What that Nginx is expected to enforce — rate limits, body size, timeouts and
which paths are reachable from outside at all — is written down in
[`edge/README.md`](edge/README.md), with a reference configuration next to it.
It is not deployed from here; it exists so a change at the edge is visible in
the repository instead of living only on the host.

`generate-env-secrets.sh` is an optional first-install helper. It fills only
empty credential assignments in `.env`, never prints their values and never
overwrites an existing value. The running stack does not need the script.

`manage-user-test-data.sh` is an optional, guarded helper for a controlled DEV
user test. It previews, refreshes or removes only the synthetic Mensa and
timetable rows owned by the `user-test` source. The app discloses the test
environment globally; individual cards keep natural labels.

Use `.env.example` for a new installation. For the existing eriklabs.eu DEV
layout, copy `.env.eriklabs-dev.example` to `.env` and fill the empty secrets
only on the VPS.

## Download without cloning the repository

Create an empty deployment directory on the VPS and download the two runtime
files plus the optional, non-secret bootstrap helper:

```bash
mkdir -p /root/dev/docker/campus
cd /root/dev/docker/campus
curl -fsSLO https://raw.githubusercontent.com/Leviora-Studio/campus-koethen/main/infrastructure/vps/compose.yaml
curl -fsSL https://raw.githubusercontent.com/Leviora-Studio/campus-koethen/main/infrastructure/vps/.env.eriklabs-dev.example -o .env
curl -fsSLO https://raw.githubusercontent.com/Leviora-Studio/campus-koethen/main/infrastructure/vps/generate-env-secrets.sh
curl -fsSLO https://raw.githubusercontent.com/Leviora-Studio/campus-koethen/main/infrastructure/vps/manage-user-test-data.sh
chmod 600 .env
chmod 700 generate-env-secrets.sh
chmod 700 manage-user-test-data.sh
```

If the repository is private, copy the files over an authenticated channel
instead (for example with `gh`, `scp`, or curl with a private token header). Do
not place a GitHub token in a public URL or shell history.

Generate all first-install database and Strapi credentials locally on the VPS:

```bash
./generate-env-secrets.sh .env
```

The command is safe to repeat: non-empty values are preserved, and the script
does not generate the later Strapi read-only API token. Edit `.env` and set
`CAMPUS_IMAGE_TAG` to the immutable
`sha-<full commit SHA>` tag from a successful GitHub Actions run. CMS and
backend must use the same tag. Leave `STRAPI_API_TOKEN` empty until the first
CMS start.

Validate interpolation without printing the resolved secret-bearing config:

```bash
docker compose config --quiet
```

If the GHCR packages are private, authenticate Docker to `ghcr.io` once on the
VPS using a dedicated fine-grained token with read access to packages:

```bash
echo "$GHCR_TOKEN" | docker login ghcr.io -u "$GITHUB_USERNAME" --password-stdin
```

This stores the credentials safely in `~/.docker/config.json` on the server
without checking them into `.env` or any repository files. Public images need no
login.

## First start

Start PostgreSQL, its idempotent bootstrap, and Strapi:

```bash
docker compose pull db db-init cms
docker compose up -d db cms
docker compose ps --all
```

Create the first Strapi administrator at the configured CMS URL. Then create a
server-side read-only API token, put it into `STRAPI_API_TOKEN` in `.env`, and
keep Strapi content unavailable without an API token.

Apply the committed application migrations and start API and worker:

```bash
docker compose pull api worker migrate
docker compose --profile migrate run --rm migrate
docker compose up -d api worker
```

The host reverse proxy should now forward the configured public CMS URL to
`CMS_BIND_ADDRESS:CMS_HOST_PORT` and the public API URL to
`API_BIND_ADDRESS:API_HOST_PORT`.

All worker cron expressions are evaluated in `WORKER_TIME_ZONE`. The generic
configuration uses `UTC`; the eriklabs.eu DEV configuration deliberately uses
`Europe/Berlin`, including its daylight-saving transitions. Invalid IANA zone
names make the backend fail configuration validation instead of silently using
the host timezone.

## Verify

With the eriklabs.eu defaults:

```bash
curl -i http://127.0.0.1:3020/_health
curl -i http://127.0.0.1:3021/health/live
curl -i http://127.0.0.1:3021/health/ready
curl -i https://strapi-dev.eriklabs.eu/_health
curl -i https://campus-backend-dev.eriklabs.eu/health/ready
docker compose ps --all
docker compose logs --since=10m --tail=200 cms api worker
```

Expected HTTP statuses are 204 for the CMS health endpoint and 200 for both API
health endpoints. `db-init` should be exited with status 0; it is a successful
one-off service, not a daemon.

After the campus-map image is deployed, review and apply the idempotent room
catalogue sync:

```bash
docker compose exec cms node dist/scripts/rooms-sync.js --dry-run
docker compose exec cms node dist/scripts/rooms-sync.js
```

## Controlled user-test dataset (DEV only)

Set `USER_TEST_DATA_ENABLED=true` only on the temporary deployment used for the
user test. The eriklabs.eu DEV example already opts in. The flag both unlocks
the write operation and makes `GET /v1/environment` advertise the deployment,
which displays the global bilingual disclosure in the app.

After migrations and the API image are current, preview and seed the rolling
dataset:

```bash
./manage-user-test-data.sh --dry-run
./manage-user-test-data.sh --seed
```

The operation is idempotent. Repeating `--seed` moves the menu window to today
and the timetable window to the current week, updates existing records and
removes older rows from this seed only. It creates meals for both configured
Köthen canteens and one selectable timetable group whose room references come
from the current canonical fictional building catalogue. It does not create a
Google calendar; configure the separate public test calendar in Strapi.

To end the user test, remove the rows first and only then set
`USER_TEST_DATA_ENABLED=false` and recreate API and worker:

```bash
./manage-user-test-data.sh --remove
docker compose up -d --force-recreate api worker
```

The environment endpoint continues disclosing synthetic content while seeded
rows remain, even if the flag is disabled too early.

## Normal rollout

Make a database and uploads backup first. Then change the single
`CAMPUS_IMAGE_TAG` value in `.env` and run:

```bash
docker compose config --quiet
docker compose pull cms api worker migrate
docker compose stop api worker
docker compose --profile migrate run --rm migrate
docker compose up -d cms
docker compose up -d api worker
docker compose ps --all
```

Nginx needs no deployment change because the host ports remain stable. An image
rollback uses the previous immutable tag, but it does not undo a database
migration.

## Persistence and secrets

Compose creates two named volumes under `COMPOSE_PROJECT_NAME`:

- `postgres_data` contains both isolated databases;
- `strapi_uploads` contains uploaded CMS files.

Back up both before upgrades and keep offsite backups with tested restores.
Never run `docker compose down --volumes` for an installation whose data must be
retained.

The committed `*.example` files contain no credentials. The filled `.env` is
ignored by Git and must exist only on the target server or in an appropriate
secret manager.
