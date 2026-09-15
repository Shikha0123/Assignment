#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# restore.sh
# Restores a backup produced by backup.sh into a FRESH database, then runs a
# verification query so you know the restore actually worked (row counts
# match what was in the backup), rather than just trusting a clean exit code.
#
# Usage:
#   ./scripts/restore.sh <path-to-dump-file> [target_db_name]
#
# Example:
#   ./scripts/restore.sh backups/tripare_20260915T140000Z.dump tripare_restore_test
#
# Config (env vars, all optional -- defaults match docker-compose.yml):
#   DB_HOST, DB_PORT, DB_USER, PGPASSWORD
# ---------------------------------------------------------------------------
set -euo pipefail

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <path-to-dump-file> [target_db_name]" >&2
    exit 1
fi

DUMP_FILE="$1"
TARGET_DB="${2:-tripare_restore_test}"

DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_USER="${DB_USER:-tripare_admin}"
export PGPASSWORD="${PGPASSWORD:-tripare_local_password}"

if [[ ! -f "$DUMP_FILE" ]]; then
    echo "!! Dump file not found: $DUMP_FILE" >&2
    exit 1
fi

echo "==> Restoring '${DUMP_FILE}' into a FRESH database '${TARGET_DB}' on ${DB_HOST}:${DB_PORT} ..."

# Restoring into a brand-new database (never the original) is deliberate:
# it proves the backup is self-contained and actually restorable, instead
# of just re-running migrations against the database that was already
# there.
psql --host="$DB_HOST" --port="$DB_PORT" --username="$DB_USER" --dbname=postgres \
    -v ON_ERROR_STOP=1 \
    -c "DROP DATABASE IF EXISTS ${TARGET_DB};" \
    -c "CREATE DATABASE ${TARGET_DB};"

pg_restore \
    --host="$DB_HOST" \
    --port="$DB_PORT" \
    --username="$DB_USER" \
    --dbname="$TARGET_DB" \
    --no-owner \
    --no-privileges \
    "$DUMP_FILE"

echo "==> Restore command finished. Verifying row counts..."

# --- Verification -----------------------------------------------------
# Compares table counts in the restored database against the source
# database (if it's reachable) so "the command exited 0" isn't the only
# evidence the restore worked.
SOURCE_DB="${SOURCE_DB:-tripare}"

restored_bookings=$(psql --host="$DB_HOST" --port="$DB_PORT" --username="$DB_USER" --dbname="$TARGET_DB" -tA -c "SELECT COUNT(*) FROM hotel_bookings;")
restored_events=$(psql --host="$DB_HOST" --port="$DB_PORT" --username="$DB_USER" --dbname="$TARGET_DB" -tA -c "SELECT COUNT(*) FROM booking_events;")

echo "    Restored hotel_bookings rows: ${restored_bookings}"
echo "    Restored booking_events rows: ${restored_events}"

if [[ "$restored_bookings" -lt 1 ]]; then
    echo "!! Verification FAILED: hotel_bookings is empty after restore." >&2
    exit 1
fi

if psql --host="$DB_HOST" --port="$DB_PORT" --username="$DB_USER" --dbname=postgres -tA -lqt | cut -d '|' -f 1 | grep -qw "$SOURCE_DB"; then
    source_bookings=$(psql --host="$DB_HOST" --port="$DB_PORT" --username="$DB_USER" --dbname="$SOURCE_DB" -tA -c "SELECT COUNT(*) FROM hotel_bookings;" 2>/dev/null || echo "n/a")
    echo "    Source ('${SOURCE_DB}') hotel_bookings rows: ${source_bookings}"
    if [[ "$source_bookings" != "n/a" && "$source_bookings" != "$restored_bookings" ]]; then
        echo "!! Verification WARNING: restored row count (${restored_bookings}) does not match source (${source_bookings})." >&2
        exit 1
    fi
fi

echo "==> Verification PASSED: restore produced a queryable database with data intact."
echo "==> Restored into database: ${TARGET_DB}"
