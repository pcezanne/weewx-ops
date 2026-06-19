# Linux / Raspberry Pi — Daemon Management

This directory will contain systemd unit files when Pi support is implemented.

## Units needed

| Unit file | Replaces | Purpose |
|-----------|----------|---------|
| `weewx.service` | `com.weewx.weewxd.plist` | Run weewxd, restart on exit |
| `weewx-cloudflare.path` | `com.weewxops.weewx-cloudflare.plist` (WatchPaths) | Watch for `deployment-complete.txt` via inotify |
| `weewx-cloudflare.service` | `com.weewxops.weewx-cloudflare.plist` | Run deployWXToCloudflare.sh on path event |
| `weewx-backup.timer` | `com.weewxops.weewx-backup.plist` (StartCalendarInterval) | Midnight daily trigger |
| `weewx-backup.service` | `com.weewxops.weewx-backup.plist` | Run rotateBackups.sh |

No caffeinate equivalent is needed — Raspberry Pi does not sleep.

## Key path differences (macOS → Linux)

| Item | macOS | Linux |
|------|-------|-------|
| WeeWX config | `/usr/local/etc/weewx/weewx-data` | `/etc/weewx` |
| SQLite DB | `/usr/local/var/weewx/weewx.sdb` | `/var/lib/weewx/weewx.sdb` |
| Output dir | `/Users/Shared/weewx-output` | `/srv/weewx-output` |
| Logs | `/Library/Logs/` | `/var/log/weewx/` |
| Wrangler | `/opt/local/bin/wrangler` (MacPorts) | `~/.npm-global/bin/wrangler` or `/usr/local/bin/wrangler` |
