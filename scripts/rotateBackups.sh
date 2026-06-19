#!/bin/bash
set -euo pipefail

DB_SRC="${DB_SRC:-/usr/local/var/weewx/weewx.sdb}"
BACKUP_DIR="${BACKUP_DIR:-/Users/Shared/Backup/Archive}"
DATE="${DATE:-$(date +%Y-%m-%d)}"
DAY_OF_MONTH="${DAY_OF_MONTH:-$(date +%d)}"
RCLONE_BIN="${RCLONE_BIN:-/usr/local/bin/rclone}"
RCLONE_CONF="${RCLONE_CONF:-/Users/Shared/rclone/rclone.conf}"
ENV_FILE="${ENV_FILE:-/usr/local/etc/weewx/.env}"

if [ -r "$ENV_FILE" ]; then
    set -a
    # shellcheck source=/dev/null
    source "$ENV_FILE"
    set +a
fi

if [ ! -f "$DB_SRC" ]; then
    echo "$(date): ERROR: Source database not found: $DB_SRC"
    exit 1
fi

/bin/mkdir -p "$BACKUP_DIR/daily"
/bin/mkdir -p "$BACKUP_DIR/monthly"

echo "$(date): Starting backup..."

# 1. Daily backup
/bin/cp "$DB_SRC" "$BACKUP_DIR/daily/weewx-$DATE.sdb"
echo "$(date): Daily backup complete: weewx-$DATE.sdb"

# 2. Monthly (promote on the 1st)
if [ "$DAY_OF_MONTH" == "01" ]; then
    /bin/cp "$DB_SRC" "$BACKUP_DIR/monthly/weewx-month-$DATE.sdb"
    echo "$(date): Monthly backup complete: weewx-month-$DATE.sdb"
fi

# 3. Retention: delete dailies older than 30 days
/usr/bin/find "$BACKUP_DIR/daily" -type f -mtime +30 -delete
echo "$(date): Daily retention pruned (>30 days)"

# 4. Retention: delete monthlies older than 365 days
/usr/bin/find "$BACKUP_DIR/monthly" -type f -mtime +365 -delete
echo "$(date): Monthly retention pruned (>365 days)"

echo "$(date): Backup complete."

sync_ok=false
if [ -n "${RCLONE_REMOTE:-}" ]; then
    for attempt in 1 2 3; do
        if "$RCLONE_BIN" --config "$RCLONE_CONF" sync "$BACKUP_DIR" "$RCLONE_REMOTE" -v; then
            echo "$(date): R2 sync complete."
            sync_ok=true
            break
        fi
        echo "$(date): R2 sync failed (attempt $attempt of 3). Waiting 60s..."
        sleep 60
    done
    if ! $sync_ok; then
        echo "$(date): WARNING: R2 sync failed after 3 attempts. Local backup is intact."
    fi
fi

if [ -n "${BACKUP_HEALTHCHECK_UUID:-}" ]; then
    if $sync_ok; then
        /usr/bin/curl -fsS -m 10 --retry 5 "https://hc-ping.com/${BACKUP_HEALTHCHECK_UUID}" > /dev/null || true
    else
        /usr/bin/curl -fsS -m 10 --retry 5 "https://hc-ping.com/${BACKUP_HEALTHCHECK_UUID}/fail" > /dev/null || true
    fi
fi
