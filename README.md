# weewx-ops — WeeWX Production Operations Stack

A high-availability, headless weather station running on Raspberry Pi or macOS. Data is collected from an Ecowitt gateway, processed by WeeWX, and published to Cloudflare Pages. The system is designed for unattended, remote operation with off-site backups and uptime monitoring. Raspberry Pi support is under active development; macOS is the current production platform.

---

## Project Goals

- **Always on.** The system runs unattended. No human intervention should be required for normal operation. launchd keeps every service alive and restarts anything that exits.
- **Resilient to network loss.** WeeWX collects and archives locally regardless of internet availability. Deployment and backup sync retry on the next cycle.
- **Data integrity over convenience.** The SQLite database is the source of truth. Backups are rotated daily and monthly. Cloudflare R2 provides off-site redundancy.
- **Atomic web deployments.** The web publish step is decoupled from data collection via a filesystem sentinel file. A failed deploy never corrupts a running collection cycle.
- **Portable.** Configuration is source-controlled. A rebuild from scratch should be possible from this repo plus a `.env` file.

---

## Architecture

The system is composed of five layers, each implemented as an independent macOS LaunchDaemon.

### Power Management
**`launchdaemons/com.weewxops.caffeinate.plist`**

Keeps the Mac awake indefinitely using `caffeinate -sim` (system sleep, idle sleep, and disk sleep prevention). Required for reliable headless operation with the lid closed.

### Core Data Collection
**`launchdaemons/com.weewx.weewxd.plist`**

Runs `weewxd` under a Python virtualenv at `/usr/local/weewx-venv`. KeepAlive ensures launchd restarts it if it exits for any reason. An explicit PATH is injected so launchd can resolve the venv binaries without a login shell.

WeeWX polls the Ecowitt gateway every 20 seconds via the local HTTP API (`user.ecowitt_http` driver). Archive records are written to SQLite every 5 minutes. On startup after a gap, the driver pulls history from the gateway's SD card to backfill missing records.

### Database Backup
**`launchdaemons/com.weewxops.weewx-backup.plist`** → **`scripts/rotateBackups.sh`**

Runs at midnight daily. Implements a simple rotation: 30 daily copies and 12 monthly copies (promoted on the 1st). Both tiers are synced to Cloudflare R2 by the deploy script.

To verify a backup without WeeWX:
`sqlite3 /path/to/backup.sdb "PRAGMA integrity_check;"`

### Event-Driven Deployment
**`launchdaemons/com.weewxops.weewx-cloudflare.plist`** → **`scripts/deployWXToCloudflare.sh`**

Uses `WatchPaths` to monitor `deployment-complete.txt` in the WeeWX output directory. When WeeWX finishes a report cycle, it writes this sentinel file, which triggers the deploy daemon — no polling, no cron race conditions.

The deploy script:
1. Waits 5 seconds for filesystem writes to settle
2. Publishes the output directory to Cloudflare Pages via Wrangler (90s timeout)
3. Syncs the local backup archive to Cloudflare R2 via rclone (120s timeout)
4. Pings the healthcheck heartbeat on full success, or the `/fail` endpoint on partial failure
5. Uses a lockfile to prevent overlapping runs; the lockfile is always removed on exit, even on crash

A `ThrottleInterval` of 60 seconds on the LaunchDaemon provides a second layer of overlap prevention.

### Log Management
Logs for all daemons are written to `/Library/Logs/`. WeeWX additionally maintains its own rotating log at `/usr/local/etc/weewx/weewx-data/log/weewxd.log` (7-day midnight rotation).

For system-level log rotation, add a newsyslog config to `/etc/newsyslog.d/` capping each log at 1MB with 5 compressed generations.

---

## Repository Layout

```
config/          WeeWX and skin configuration
launchdaemons/   macOS LaunchDaemon plists
scripts/         Shell scripts run by the daemons
tests/           Self-contained bash test suites
install.sh       Deploys everything to its live location
.env.example     Required credentials (copy to .env and fill in)
```

---

## Setup

**Prerequisites:** WeeWX installed in `/usr/local/weewx-venv`, Wrangler at `/opt/local/bin/wrangler` (MacPorts), rclone at `/usr/local/bin/rclone`, an rclone config at `/Users/Shared/rclone/rclone.conf`.

1. Clone this repo.
2. Copy `.env.example` to `.env` and fill in all values — station identity, gateway IP, and all credentials.
3. Create the shared directories:
   - `/Users/Shared/weewx-output`
   - `/Users/Shared/Backup/Archive/daily`
   - `/Users/Shared/Backup/Archive/monthly`
4. Run `sudo bash install.sh` — this installs all configs, scripts, and plists, then reloads each LaunchDaemon.

---

## Operations

### Routine

- **Logs:** `/Library/Logs/weewx-cloudflare.out` for deploy activity; `weewxd.log` for WeeWX internals.
- **Uptime monitoring:** healthchecks.io pings on every successful deploy cycle (~every 5 minutes).
- **Backups:** verify with `sqlite3 ... "PRAGMA integrity_check;"` before trusting a restore.

### macOS-Specific Issues

**"Operation not permitted" after config changes** — Reboot. launchd caches paths aggressively and a reboot is the reliable fix.

**Quarantine blocking scripts** — Downloaded scripts may be flagged by Gatekeeper. Run `xattr -d com.apple.quarantine /path/to/script.sh` to unblock.

**Lockfile left behind** — If `/tmp/weewx-deploy.lock` persists after a crash, remove it manually. The deploy script uses a trap to prevent this, but a hard kill (SIGKILL) can still leave it.

### Venv Corruption

If WeeWX fails with `ModuleNotFoundError`, the virtualenv is disposable:

1. `sudo rm -rf /usr/local/weewx-venv`
2. `sudo python3 -m venv /usr/local/weewx-venv`
3. `sudo chown -R $(whoami):staff /usr/local/weewx-venv`
4. `/usr/local/weewx-venv/bin/pip install weewx requests pyserial six certifi`
5. Reinstall the ecowitt_http driver into the venv.

### Driver Reconfiguration

When rebuilding or migrating hardware, relink the station driver explicitly:

`/usr/local/weewx-venv/bin/weectl station reconfigure --driver=user.ecowitt_http --config=/usr/local/etc/weewx/weewx-data/weewx.conf`

---

## Future: Migration to Raspberry Pi

The architecture is intentionally portable. The main differences on Linux:

| Concern | macOS (current) | Raspberry Pi |
|---------|----------------|--------------|
| Keep-awake | `caffeinate` LaunchDaemon | Not needed |
| Daemon manager | `launchctl` / `.plist` | `systemctl` / `.service` |
| Log rotation | `newsyslog` | `logrotate` |
| Power resilience | Built-in battery (laptop) | External UPS HAT required |
| Security flags | TCC + quarantine xattr | Standard chmod/chown |

The `scripts/` and `config/` directories are platform-agnostic. Only `launchdaemons/` needs to be replaced with systemd unit files.

---

## Running Tests

`bash tests/test_rotate_backups.sh`
`bash tests/test_deploy.sh`

---

## Authors

Originally written by Google Gemini. Developed further by Anthropic Claude Code. Both directed and prompted by Paul Cezanne.

## License

Copyright (C) 2026 Paul Cezanne. Licensed under the [GNU General Public License v3](LICENSE).
