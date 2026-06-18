#!/bin/bash
# Local Rotation & Staging for Cloud Egress
DB_SRC="/usr/local/var/weewx/weewx.sdb"
BACKUP_DIR="/Users/Shared/Backup/Archive"
DATE=$(date +%Y-%m-%d)
DAY_OF_MONTH=$(date +%d)

/bin/mkdir -p "$BACKUP_DIR/daily"
/bin/mkdir -p "$BACKUP_DIR/monthly"

# 1. Perform the Daily Backup
/bin/cp "$DB_SRC" "$BACKUP_DIR/daily/weewx-$DATE.sdb"

# 2. If it's the 1st of the month, "Promote" to Monthly
if [ "$DAY_OF_MONTH" == "01" ]; then
    /bin/cp "$DB_SRC" "$BACKUP_DIR/monthly/weewx-month-$DATE.sdb"
fi

# 3. Retention: Delete dailies older than 30 days
/usr/bin/find "$BACKUP_DIR/daily" -type f -mtime +30 -delete

# 4. Retention: Delete monthlies older than 365 days
/usr/bin/find "$BACKUP_DIR/monthly" -type f -mtime +365 -delete