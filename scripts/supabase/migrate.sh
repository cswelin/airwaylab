#!/bin/sh
# Applies supabase/migrations/*.sql to the self-hosted Postgres, in order,
# tracking what's already been applied so re-runs only pick up new files.
# Runs inside a throwaway postgres:17-alpine container (see docker-compose.yml)
# after auth and storage have created their schemas.
set -eu

export PGHOST="${POSTGRES_HOST:-db}"
export PGPORT="${POSTGRES_PORT:-5432}"
export PGUSER=postgres
export PGPASSWORD="${POSTGRES_PASSWORD}"
export PGDATABASE="${POSTGRES_DB:-postgres}"

psql -v ON_ERROR_STOP=1 -c "
  create table if not exists public._app_migrations (
    filename text primary key,
    applied_at timestamptz not null default now()
  );
"

for f in /migrations/*.sql; do
  name=$(basename "$f")
  already=$(psql -tA -c "select 1 from public._app_migrations where filename = '$name'")
  if [ "$already" = "1" ]; then
    echo "skip  $name (already applied)"
    continue
  fi
  echo "apply $name"
  psql -v ON_ERROR_STOP=1 -f "$f"
  psql -c "insert into public._app_migrations (filename) values ('$name')"
done

echo "migrations complete"
