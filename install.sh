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
envsubst '${WU_PASSWORD}' < "$SCRIPT_DIR/weewx.conf" | sudo tee "$WEEWX_CONF_DIR/weewx.conf" > /dev/null

echo "Installing deploy and backup scripts..."
sudo cp "$SCRIPT_DIR/deployWXToCloudfare.sh" "$WEEWX_BIN/deployWXToCloudfare.sh"
sudo chmod +x "$WEEWX_BIN/deployWXToCloudfare.sh"
sudo cp "$SCRIPT_DIR/rotateBackups.sh" "$WEEWX_BIN/rotateBackups.sh"
sudo chmod +x "$WEEWX_BIN/rotateBackups.sh"

echo "Installing LaunchDaemons..."
for plist in com.weewx.weewxd.plist com.enkilabs.weewx-cloudfare.plist com.enkilabs.weewx-backup.plist com.enkilabs.caffeinate.plist; do
    sudo cp "$SCRIPT_DIR/$plist" "$LAUNCH_DAEMONS/$plist"
done

echo "Done. Run 'sudo launchctl load /Library/LaunchDaemons/<plist>' to activate any new daemons."
