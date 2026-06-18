#!/bin/bash
set -euo pipefail

# Local Rotation & Staging for Cloud Egress
DB_SRC="${DB_SRC:-/usr/local/var/weewx/weewx.sdb}"
BACKUP_DIR="${BACKUP_DIR:-/Users/Shared/Backup/Archive}"
DATE="${DATE:-$(date +%Y-%m-%d)}"
DAY_OF_MONTH="${DAY_OF_MONTH:-$(date +%d)}"

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
