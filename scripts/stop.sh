#!/bin/bash
set -euo pipefail

LAUNCH_DAEMONS="/Library/LaunchDaemons"

if [ "$(uname -s)" != "Darwin" ]; then
    echo "Error: stop.sh is macOS only. Use 'sudo systemctl stop weewx' on Linux."
    exit 1
fi

if [ "$(id -u)" -ne 0 ]; then
    echo "Error: must run as root. Use: sudo stop.sh"
    exit 1
fi

for plist in com.weewx.weewxd.plist com.weewxops.weewx-cloudflare.plist com.weewxops.weewx-backup.plist com.weewxops.caffeinate.plist; do
    target="$LAUNCH_DAEMONS/$plist"
    if [ -f "$target" ]; then
        echo "Unloading $plist..."
        launchctl unload "$target" 2>/dev/null || true
    else
        echo "  (skipping $plist — not installed)"
    fi
done

echo "Done. Run 'sudo install.sh' to reinstall and restart."
