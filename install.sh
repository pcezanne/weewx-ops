#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"
WEEWX_CONF_DIR="/usr/local/etc/weewx/weewx-data"
WEEWX_BIN="/usr/local/bin"
LAUNCH_DAEMONS="/Library/LaunchDaemons"

if [ ! -f "$ENV_FILE" ]; then
    echo "Error: $ENV_FILE not found. Copy .env.example to .env and fill in your credentials."
    exit 1
fi

set -a
source "$ENV_FILE"
set +a

echo "Installing .env to /usr/local/etc/weewx/.env..."
sudo cp "$ENV_FILE" /usr/local/etc/weewx/.env
sudo chmod 600 /usr/local/etc/weewx/.env

echo "Installing weewx.conf (with credential substitution)..."
envsubst '${WU_PASSWORD} ${WU_STATION_ID} ${WEEWX_LOCATION} ${WEEWX_LATITUDE} ${WEEWX_LONGITUDE} ${WEEWX_ALTITUDE} ${ECOWITT_IP} ${CLOUDFLARE_PROJECT_NAME} ${RCLONE_REMOTE}' \
    < "$SCRIPT_DIR/config/weewx.conf" | sudo tee "$WEEWX_CONF_DIR/weewx.conf" > /dev/null

echo "Installing scripts..."
sudo cp "$SCRIPT_DIR/scripts/deployWXToCloudflare.sh" "$WEEWX_BIN/deployWXToCloudflare.sh"
sudo chmod +x "$WEEWX_BIN/deployWXToCloudflare.sh"
sudo cp "$SCRIPT_DIR/scripts/rotateBackups.sh" "$WEEWX_BIN/rotateBackups.sh"
sudo chmod +x "$WEEWX_BIN/rotateBackups.sh"

echo "Installing LaunchDaemons..."
for plist in com.weewx.weewxd.plist com.weewxops.weewx-cloudflare.plist com.weewxops.weewx-backup.plist com.weewxops.caffeinate.plist; do
    sudo cp "$SCRIPT_DIR/launchdaemons/$plist" "$LAUNCH_DAEMONS/$plist"
    echo "  Reloading $plist..."
    sudo launchctl unload "$LAUNCH_DAEMONS/$plist" 2>/dev/null || true
    sudo launchctl load "$LAUNCH_DAEMONS/$plist"
done

echo "Done."
