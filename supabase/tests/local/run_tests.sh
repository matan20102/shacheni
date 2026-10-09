#!/usr/bin/env bash
# Rebuilds a throwaway database from the migrations and runs every tests/*_test.sql against it.
# Needs a local PostgreSQL 17 server (no Docker / Supabase CLI). Usage, from the repo root:
#   PGBIN=/path/to/pgsql/bin PGPORT=54329 supabase/tests/local/run_tests.sh
set -euo pipefail
cd "$(dirname "$0")/../.."
PSQL="${PGBIN:+$PGBIN/}psql -U ${PGUSER:-postgres} -p ${PGPORT:-5432} -q -v ON_ERROR_STOP=1"
DB=shacheni_test

$PSQL -d postgres -c "drop database if exists $DB" -c "create database $DB"
$PSQL -d $DB -f tests/local/supabase_stub.sql
for f in migrations/*.sql; do
  echo "apply  $f"
  $PSQL -d $DB -1 -f "$f"
done
for f in tests/*_test.sql; do
  echo "test   $f"
  $PSQL -d $DB -f "$f"
done
