#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# backup.sh
# Creates a timestamped, compressed dump of the tripare database.
#
# Usage:
#   ./scripts/backup.sh
#
# Config (env vars, all optional -- defaults match docker-compose.yml):
#   DB_HOST, DB_PORT, DB_NAME, DB_USER, PGPASSWORD, BACKUP_DIR
# ---------------------------------------------------------------------------
set -euo pipefail

DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5434}"
DB_NAME="${DB_NAME:-tripare}"
DB_USER="${DB_USER:-tripare_admin}"
export PGPASSWORD="${PGPASSWORD:-tripare_local_password}"
BACKUP_DIR="${BACKUP_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/backups}"

mkdir -p "$BACKUP_DIR"

TIMESTAMP="$(date -u +%Y%m%dT%H%M%SZ)"
BACKUP_FILE="${BACKUP_DIR}/${DB_NAME}_${TIMESTAMP}.dump"

echo "==> Backing up '${DB_NAME}' from ${DB_HOST}:${DB_PORT} ..."

# -F c = custom format: compressed, and restorable selectively/in parallel
# with pg_restore (unlike a plain .sql text dump).
/usr/lib/postgresql/16/bin/pg_dump \
    --host="$DB_HOST" \
    --port="$DB_PORT" \
    --username="$DB_USER" \
    --format=custom \
    --file="$BACKUP_FILE" \
    "$DB_NAME"

DUMP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
echo "==> Backup complete: ${BACKUP_FILE} (${DUMP_SIZE})"

# Basic sanity check: make sure pg_restore can at least read the archive's
# table of contents back out of the file we just wrote. This catches a
# truncated/corrupt dump immediately rather than at restore time.
if /usr/lib/postgresql/16/bin/pg_restore --list "$BACKUP_FILE" > /dev/null; then
    echo "==> Verified: backup archive is readable (pg_restore --list succeeded)."
else
    echo "!! Backup verification failed: pg_restore could not read the archive." >&2
    exit 1
fi

# Keep only the last 7 local backups so this doesn't grow unbounded; the
# retention policy that actually matters (RDS automated backups) is
# controlled by the Terraform backup_retention_period variable, not by this
# script.
ls -1t "${BACKUP_DIR}"/${DB_NAME}_*.dump 2>/dev/null | tail -n +8 | xargs -r rm -f

echo "==> Latest backup: ${BACKUP_FILE}"
echo "$BACKUP_FILE"
