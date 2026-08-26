#!/bin/sh
set -eu
umask 077

project_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
backup_dir="$project_dir/backups"
postgres_dir="$backup_dir/postgres"
uploads_dir="$backup_dir/uploads"
stamp=$(date -u +%Y%m%dT%H%M%SZ)

mkdir -p "$postgres_dir" "$uploads_dir"
cd "$project_dir"

for database in campus_cms_dev campus_app_dev; do
  target="$postgres_dir/${database}_${stamp}.dump"
  docker compose exec -T db pg_dump \
    --username campus_admin \
    --format custom \
    --dbname "$database" > "$target"
  test -s "$target"
done

uploads_target="$uploads_dir/strapi_uploads_${stamp}.tar.gz"
docker compose exec -T cms tar -C /opt/app/public -czf - uploads > "$uploads_target"
test -s "$uploads_target"

# Local rollout safety copies only. Offsite backups and restore tests remain a
# release gate and must not be inferred from this 14-day local retention.
python3 - "$backup_dir" <<'PY'
from pathlib import Path
import sys
import time

root = Path(sys.argv[1])
cutoff = time.time() - 14 * 24 * 60 * 60
for pattern in ('*.dump', '*.tar.gz'):
    for path in root.rglob(pattern):
        if path.is_file() and path.stat().st_mtime < cutoff:
            path.unlink()
PY

printf '%s\n' "Local backup completed: $stamp"
