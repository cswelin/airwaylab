#!/bin/sh
# Bootstraps the self-hosted Postgres schema, mirroring scripts/db-replay.sh's
# GATE mode: the AirwayLab migration history is NOT replayable from scratch
# (see supabase/baseline.sql header, PR #984) because a few objects — notably
# public.waitlist — exist in prod but were never captured in a migration.
# Replaying supabase/migrations/*.sql from 001 onward fails on those gaps.
#
# So: apply supabase/baseline.sql (a structure-only snapshot of prod as of
# the cut in supabase/baseline.cut), then only replay migrations numbered
# after that cut. Unlike db-replay.sh's CI usage, we skip ci-db-preshim.sql
# entirely — this stack has a real GoTrue/Storage-managed auth+storage
# schema already, not a plain-Postgres stand-in, so baseline.sql's
# storage.* statements are expected to fail as "already exists" (real
# Storage API got there first) and are applied non-fatally for that reason.
#
# Runs inside a throwaway postgres:17-alpine container (see
# docker-compose.yml) after auth and storage have created their schemas.
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

baseline_marker="supabase/baseline.sql"
baselined=$(psql -tA -c "select 1 from public._app_migrations where filename = '$baseline_marker'")

if [ "$baselined" = "1" ]; then
  echo "skip  $baseline_marker (already applied)"
elif [ -f /baseline/baseline.sql ]; then
  echo "apply $baseline_marker (storage.* already-exists errors below are expected)"
  PGOPTIONS="-c search_path=public,storage,extensions" psql -q -f /baseline/baseline.sql
  if [ -f /baseline/baseline.grants.sql ]; then
    echo "apply supabase/baseline.grants.sql"
    psql -v ON_ERROR_STOP=1 -q -f /baseline/baseline.grants.sql
  fi
  psql -c "insert into public._app_migrations (filename) values ('$baseline_marker')"
else
  echo "WARNING: supabase/baseline.sql not found — falling back to full replay from 001, which is expected to fail on out-of-band prod objects (see supabase/baseline.sql header)"
fi

cut=000
[ -f /baseline/baseline.cut ] && cut="$(cat /baseline/baseline.cut)"

for f in /migrations/*.sql; do
  name=$(basename "$f")
  n=$(echo "$name" | grep -oE '^[0-9]+' || echo 000)
  if [ -f /baseline/baseline.sql ] && { [ "$n" \< "$cut" ] || [ "$n" = "$cut" ]; }; then
    continue # folded into the baseline already
  fi
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
