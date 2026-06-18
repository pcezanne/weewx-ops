#!/bin/bash

#
# This should be in /usr/local/bin/deployWXToCloudflare.sh
#
export PATH="/opt/local/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

# --- CONFIG ---
WRANGLER="/opt/local/bin/wrangler"
SOURCE_DIR="/Users/Shared/weewx-output"
PROJECT_NAME="wx-notthepainter"
LOG="/Library/Logs/weewx-cloudflare.out"

# --- AUTH ---
source /usr/local/etc/weewx/.env
export CLOUDFLARE_API_TOKEN
export CLOUDFLARE_ACCOUNT_ID
export CI=true

# --- 1. SETTLE TIME ---
# Give the filesystem 5 seconds to finish writing images/JSON
sleep 5

# --- 1A. Backup to iCloud ---

# --- PATHS ---
LIVE_DB="/usr/local/var/weewx/weewx.sdb"

# --- PREVENT OVERLAP (Lockfile) ---
LOCKFILE="/tmp/weewx-deploy.lock"
if [ -e "$LOCKFILE" ]; then
    echo "Deployment already in progress. Skipping." >> "$LOG"
    exit 1
fi
touch "$LOCKFILE"

# --- DEPLOY WITH 90s TIMEOUT ---
cd "$SOURCE_DIR" || exit 1

echo "Starting deploy at $(date)..." >> "$LOG"

# Using gtimeout (from MacPorts coreutils) to kill it if it hangs
/opt/local/bin/gtimeout 90s $WRANGLER pages deploy . --project-name "$PROJECT_NAME" --branch main --commit-dirty=true >> "$LOG" 2>&1


# Define the paths clearly
RCLONE_BIN="/usr/local/bin/rclone"
RCLONE_CONF="/Users/Shared/rclone/rclone.conf"
SOURCE_DIR="/Users/Shared/Backup/Archive"
REMOTE_NAME="cloudflare:pcezanne-weather-backups"

# The command
$RCLONE_BIN --config "$RCLONE_CONF" sync "$SOURCE_DIR" "$REMOTE_NAME" -v

# Ping the heartbeat
/usr/bin/curl -m 10 --retry 5 "https://hc-ping.com/${HEALTHCHECK_UUID}"

# --- CLEANUP ---
rm -f "$LOCKFILE"
echo "Cycle finished at $(date)" >> "$LOG"