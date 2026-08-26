#!/bin/sh
# Campus Köthen App · AGPL-3.0-only
# Copyright © 2026 Leviora Studio and Jona Loreen Sommer

set -eu

usage() {
  printf '%s\n' \
    'Usage: manage-user-test-data.sh --dry-run | --seed | --remove' \
    '  --dry-run  show the rolling date range and record counts; write nothing' \
    '  --seed     idempotently create or refresh the controlled user-test data' \
    '  --remove   remove only records owned by the user-test data source'
}

if [ "$#" -ne 1 ]; then
  usage >&2
  exit 2
fi

case "$1" in
  --dry-run)
    seed_argument='--dry-run'
    ;;
  --seed)
    seed_argument=''
    ;;
  --remove)
    seed_argument='--remove'
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac

docker compose config --quiet

if [ -n "$seed_argument" ]; then
  docker compose --profile user-test-seed run --rm user-test-data "$seed_argument"
else
  docker compose --profile user-test-seed run --rm user-test-data
fi
