#!/bin/sh
set -eu

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
cd "$project_dir"

# `--quiet` validates interpolation and structure without printing resolved
# secret-bearing configuration.
docker compose config --quiet
docker compose ps

docker compose exec -T db pg_isready \
  --username campus_admin \
  --dbname postgres

docker compose exec -T db psql \
  --username campus_admin \
  --dbname postgres \
  --tuples-only \
  --no-align \
  --command "SELECT datname FROM pg_database WHERE datname IN ('campus_cms_dev','campus_app_dev') ORDER BY datname;"

cms_status=$(curl -sS -o /dev/null --max-time 15 -w '%{http_code}' \
  https://cms-dev.myaioffice.de/_health)
test "$cms_status" = '204'

curl -fsS --max-time 15 https://api-dev.myaioffice.de/health/live >/dev/null
curl -fsS --max-time 15 https://api-dev.myaioffice.de/health/ready >/dev/null

printf '%s\n' 'Campus Köthen DEV verification passed.'
