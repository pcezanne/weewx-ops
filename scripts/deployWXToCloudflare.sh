#!/bin/bash
set -euo pipefail

#
# This should be in /usr/local/bin/deployWXToCloudflare.sh
#
export PATH="/opt/local/bin:/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin"

# --- CONFIG ---
WRANGLER="${WRANGLER:-/opt/local/bin/wrangler}"
SOURCE_DIR="${SOURCE_DIR:-/Users/Shared/weewx-output}"
LOG="${LOG:-/Library/Logs/weewx-cloudflare.out}"
LOCKFILE="${LOCKFILE:-/tmp/weewx-deploy.lock}"
ENV_FILE="${ENV_FILE:-/usr/local/etc/weewx/.env}"

# --- AUTH ---
set -a
source "$ENV_FILE"
set +a
export CI=true

# Values that come from .env
REMOTE_NAME="${RCLONE_REMOTE}"
PROJECT_NAME="${CLOUDFLARE_PROJECT_NAME}"

# --- PREVENT OVERLAP ---
if [ -e "$LOCKFILE" ]; then
    echo "$(date): Deployment already in progress. Skipping." >> "$LOG"
    exit 1
fi
touch "$LOCKFILE"
trap 'rm -f "$LOCKFILE"' EXIT

# --- SETTLE TIME ---
# Give the filesystem 5 seconds to finish writing images/JSON
sleep 5

# --- DEPLOY ---
cd "$SOURCE_DIR"
echo "$(date): Starting deploy..." >> "$LOG"
if /opt/local/bin/gtimeout 90s "$WRANGLER" pages deploy . \
    --project-name "$PROJECT_NAME" --branch main --commit-dirty=true >> "$LOG" 2>&1; then
    /usr/bin/curl -fsS -m 10 --retry 5 "https://hc-ping.com/${HEALTHCHECK_UUID}" >> "$LOG" 2>&1 || true
    echo "$(date): Cycle complete." >> "$LOG"
else
    echo "$(date): Deploy FAILED" >> "$LOG"
    /usr/bin/curl -fsS -m 10 --retry 5 "https://hc-ping.com/${HEALTHCHECK_UUID}/fail" >> "$LOG" 2>&1 || true
    echo "$(date): Cycle finished with errors." >> "$LOG"
fi
