#!/bin/sh
# Campus Köthen — create BOTH application databases with their OWN non-superuser roles.
#
#   campus_app_local  owned by campus_app  — Campus API + worker only
#   campus_cms_local  owned by campus_cms  — Strapi only
#
# The image bootstraps POSTGRES_USER as a SUPERUSER, which would bypass every
# privilege check. That bootstrap role is therefore `postgres` and is used only
# here; neither application role is a superuser, and neither can connect to the
# other's database. This mirrors the server setup.
#
# Runs exactly once, on first initialisation of an empty data directory.

set -eu

: "${APP_DB_NAME:?APP_DB_NAME is required}"
: "${APP_DB_USER:?APP_DB_USER is required}"
: "${APP_DB_PASSWORD:?APP_DB_PASSWORD is required}"
: "${CMS_DB_NAME:?CMS_DB_NAME is required}"
: "${CMS_DB_USER:?CMS_DB_USER is required}"
: "${CMS_DB_PASSWORD:?CMS_DB_PASSWORD is required}"
: "${APP_SHADOW_DB_NAME:=campus_app_shadow}"

# Passwords travel as psql variables, never interpolated into SQL text.
psql -v ON_ERROR_STOP=1 \
  --username "$POSTGRES_USER" \
  --dbname "$POSTGRES_DB" \
  -v app_user="$APP_DB_USER" -v app_password="$APP_DB_PASSWORD" -v app_db="$APP_DB_NAME" \
  -v cms_user="$CMS_DB_USER" -v cms_password="$CMS_DB_PASSWORD" -v cms_db="$CMS_DB_NAME" \
  -v shadow_db="$APP_SHADOW_DB_NAME" <<'SQL'
-- Plain LOGIN roles: NOSUPERUSER, NOCREATEDB, NOCREATEROLE by default.
CREATE ROLE :"app_user" WITH LOGIN PASSWORD :'app_password';
CREATE ROLE :"cms_user" WITH LOGIN PASSWORD :'cms_password';

CREATE DATABASE :"app_db" OWNER :"app_user";
CREATE DATABASE :"cms_db" OWNER :"cms_user";

-- Shadow database for `prisma migrate dev`. It exists only for LOCAL
-- development: Prisma would otherwise need CREATEDB on the application role,
-- which we deliberately do not grant. `prisma migrate deploy`, used on the
-- server, never touches a shadow database.
CREATE DATABASE :"shadow_db" OWNER :"app_user";

-- Nobody may connect by default; each role is granted only its own databases.
REVOKE CONNECT ON DATABASE :"app_db"    FROM PUBLIC;
REVOKE CONNECT ON DATABASE :"cms_db"    FROM PUBLIC;
REVOKE CONNECT ON DATABASE :"shadow_db" FROM PUBLIC;
GRANT  CONNECT ON DATABASE :"app_db"    TO :"app_user";
GRANT  CONNECT ON DATABASE :"shadow_db" TO :"app_user";
GRANT  CONNECT ON DATABASE :"cms_db"    TO :"cms_user";
SQL

# Lock the public schema inside each database down to its owner.
for pair in "$APP_DB_NAME:$APP_DB_USER" "$APP_SHADOW_DB_NAME:$APP_DB_USER" "$CMS_DB_NAME:$CMS_DB_USER"; do
  db=$(echo "$pair" | cut -d: -f1)
  owner=$(echo "$pair" | cut -d: -f2)
  psql -v ON_ERROR_STOP=1 \
    --username "$POSTGRES_USER" \
    --dbname "$db" \
    -v owner="$owner" <<'SQL'
REVOKE ALL ON SCHEMA public FROM PUBLIC;
GRANT  ALL ON SCHEMA public TO :"owner";
SQL
done

echo "[initdb] created ${APP_DB_NAME} (owner ${APP_DB_USER}) and ${CMS_DB_NAME} (owner ${CMS_DB_USER})"
echo "[initdb] both roles are non-superuser; cross-database CONNECT revoked"
