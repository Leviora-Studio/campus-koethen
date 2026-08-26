#!/bin/sh
set -eu

# Generate the first-install credentials in a prepared VPS .env without ever
# printing their values. Existing non-empty values are deliberately preserved,
# so rerunning this helper cannot silently rotate a live installation.

umask 077

if [ "$#" -gt 1 ]; then
  printf 'Usage: %s [ENV_FILE]\n' "$0" >&2
  exit 1
fi
if [ "$#" -eq 1 ]; then
  env_file=$1
else
  env_file=.env
fi

case "$env_file" in
  -*)
    printf '%s\n' 'The environment file path must not start with a dash.' >&2
    exit 1
    ;;
esac

if [ ! -f "$env_file" ]; then
  printf 'Environment file not found: %s\n' "$env_file" >&2
  exit 1
fi

if [ -L "$env_file" ]; then
  printf 'Refusing to replace a symbolic link: %s\n' "$env_file" >&2
  exit 1
fi

if ! command -v openssl >/dev/null 2>&1; then
  printf '%s\n' 'openssl is required but was not found in PATH.' >&2
  exit 1
fi

credential_keys='
POSTGRES_ADMIN_PASSWORD
CMS_DATABASE_PASSWORD
APP_DATABASE_PASSWORD
STRAPI_APP_KEYS
STRAPI_API_TOKEN_SALT
STRAPI_ADMIN_JWT_SECRET
STRAPI_TRANSFER_TOKEN_SALT
STRAPI_ENCRYPTION_KEY
'

# Refuse malformed templates instead of guessing which duplicate or missing
# assignment should receive a secret.
for credential_key in $credential_keys; do
  assignment_count=$(awk -F= -v wanted="$credential_key" '
    $1 == wanted { count++ }
    END { print count + 0 }
  ' "$env_file")
  if [ "$assignment_count" -ne 1 ]; then
    printf 'Expected exactly one %s assignment in %s, found %s.\n' \
      "$credential_key" "$env_file" "$assignment_count" >&2
    exit 1
  fi
done

generate_secret() {
  openssl rand -hex 32
}

postgres_admin_password=$(generate_secret)
cms_database_password=$(generate_secret)
app_database_password=$(generate_secret)
strapi_app_keys="$(generate_secret),$(generate_secret),$(generate_secret),$(generate_secret)"
strapi_api_token_salt=$(generate_secret)
strapi_admin_jwt_secret=$(generate_secret)
strapi_transfer_token_salt=$(generate_secret)
strapi_encryption_key=$(generate_secret)

temporary_file=$(mktemp "$env_file.tmp.XXXXXX")
cleanup() {
  if [ -n "$temporary_file" ] && [ -f "$temporary_file" ]; then
    rm -f "$temporary_file"
  fi
}
trap cleanup 0 HUP INT TERM

generated_count=0
while IFS= read -r line || [ -n "$line" ]; do
  case "$line" in
    'POSTGRES_ADMIN_PASSWORD=')
      printf 'POSTGRES_ADMIN_PASSWORD=%s\n' "$postgres_admin_password"
      generated_count=$((generated_count + 1))
      ;;
    'CMS_DATABASE_PASSWORD=')
      printf 'CMS_DATABASE_PASSWORD=%s\n' "$cms_database_password"
      generated_count=$((generated_count + 1))
      ;;
    'APP_DATABASE_PASSWORD=')
      printf 'APP_DATABASE_PASSWORD=%s\n' "$app_database_password"
      generated_count=$((generated_count + 1))
      ;;
    'STRAPI_APP_KEYS=')
      printf 'STRAPI_APP_KEYS=%s\n' "$strapi_app_keys"
      generated_count=$((generated_count + 1))
      ;;
    'STRAPI_API_TOKEN_SALT=')
      printf 'STRAPI_API_TOKEN_SALT=%s\n' "$strapi_api_token_salt"
      generated_count=$((generated_count + 1))
      ;;
    'STRAPI_ADMIN_JWT_SECRET=')
      printf 'STRAPI_ADMIN_JWT_SECRET=%s\n' "$strapi_admin_jwt_secret"
      generated_count=$((generated_count + 1))
      ;;
    'STRAPI_TRANSFER_TOKEN_SALT=')
      printf 'STRAPI_TRANSFER_TOKEN_SALT=%s\n' "$strapi_transfer_token_salt"
      generated_count=$((generated_count + 1))
      ;;
    'STRAPI_ENCRYPTION_KEY=')
      printf 'STRAPI_ENCRYPTION_KEY=%s\n' "$strapi_encryption_key"
      generated_count=$((generated_count + 1))
      ;;
    *)
      printf '%s\n' "$line"
      ;;
  esac
done < "$env_file" > "$temporary_file"

chmod 600 "$temporary_file"
mv "$temporary_file" "$env_file"
temporary_file=''
trap - 0 HUP INT TERM

if [ "$generated_count" -eq 0 ]; then
  printf '%s\n' 'No empty credential fields found; existing values were left unchanged.'
else
  printf 'Generated %s credential field(s) in %s. No secret values were printed.\n' \
    "$generated_count" "$env_file"
fi

printf '%s\n' 'CAMPUS_IMAGE_TAG remains manual: use a successful immutable sha- tag.'
printf '%s\n' 'STRAPI_API_TOKEN remains manual: create it in Strapi Admin after the CMS starts.'
