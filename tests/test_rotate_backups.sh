#!/bin/bash
# Tests for scripts/rotateBackups.sh
# Usage: bash tests/test_rotate_backups.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$SCRIPT_DIR/scripts/rotateBackups.sh"
PASS=0
FAIL=0

assert() {
    local desc="$1"
    if eval "$2"; then
        echo "  PASS: $desc"
        PASS=$((PASS + 1))
    else
        echo "  FAIL: $desc"
        FAIL=$((FAIL + 1))
    fi
}

date_offset() {
    local days="$1"
    if date --version >/dev/null 2>&1; then
        date -d "-${days} days" +%Y%m%d%H%M
    else
        date -v-${days}d +%Y%m%d%H%M
    fi
}

TMPDIR_TEST=$(mktemp -d)
FAKE_DB="$TMPDIR_TEST/weewx.sdb"
BACKUP_ROOT="$TMPDIR_TEST/backup"
touch "$FAKE_DB"

cleanup() { rm -rf "$TMPDIR_TEST"; }
trap cleanup EXIT

run() {
    DB_SRC="$FAKE_DB" BACKUP_DIR="$BACKUP_ROOT" DATE="$1" DAY_OF_MONTH="$2" bash "$SCRIPT" > /dev/null
}

echo "=== test_rotate_backups.sh ==="

echo ""
echo "-- daily backup created --"
run "2026-06-18" "18"
assert "daily file exists" "[ -f '$BACKUP_ROOT/daily/weewx-2026-06-18.sdb' ]"
assert "monthly NOT created on non-1st" "[ ! -f '$BACKUP_ROOT/monthly/weewx-month-2026-06-18.sdb' ]"

echo ""
echo "-- monthly backup on the 1st --"
run "2026-06-01" "01"
assert "monthly file exists" "[ -f '$BACKUP_ROOT/monthly/weewx-month-2026-06-01.sdb' ]"

echo ""
echo "-- retention deletes old files --"
OLD_DAILY="$BACKUP_ROOT/daily/weewx-2026-01-01.sdb"
OLD_MONTHLY="$BACKUP_ROOT/monthly/weewx-month-2025-01-01.sdb"
touch "$OLD_DAILY" "$OLD_MONTHLY"
touch -t "$(date_offset 31)" "$OLD_DAILY"
touch -t "$(date_offset 366)" "$OLD_MONTHLY"
run "2026-06-18" "18"
assert "old daily deleted (>30d)" "[ ! -f '$OLD_DAILY' ]"
assert "old monthly deleted (>365d)" "[ ! -f '$OLD_MONTHLY' ]"

echo ""
echo "-- recent files are kept --"
RECENT_DAILY="$BACKUP_ROOT/daily/weewx-2026-06-10.sdb"
touch "$RECENT_DAILY"
touch -t "$(date_offset 5)" "$RECENT_DAILY"
run "2026-06-18" "18"
assert "recent daily kept" "[ -f '$RECENT_DAILY' ]"

echo ""
echo "-- missing source DB exits non-zero --"
DB_SRC="/nonexistent/weewx.sdb" BACKUP_DIR="$BACKUP_ROOT" DATE="2026-06-18" DAY_OF_MONTH="18" \
    bash "$SCRIPT" > /dev/null && result=0 || result=$?
assert "exits non-zero on missing DB" "[ ${result:-0} -ne 0 ]"

echo ""
echo "-- healthcheck: success ping when no sync configured --"
MOCK_BIN="$TMPDIR_TEST/bin"
mkdir -p "$MOCK_BIN"
PING_LOG="$TMPDIR_TEST/ping.log"
cat > "$MOCK_BIN/curl" <<MOCKEOF
#!/bin/bash
echo "\$@" >> "$PING_LOG"
MOCKEOF
cat > "$MOCK_BIN/sleep" <<'MOCKEOF'
#!/bin/bash
exit 0
MOCKEOF
chmod +x "$MOCK_BIN/curl" "$MOCK_BIN/sleep"
DB_SRC="$FAKE_DB" BACKUP_DIR="$BACKUP_ROOT" DATE="2026-06-18" DAY_OF_MONTH="18" \
    RCLONE_REMOTE="" BACKUP_HEALTHCHECK_UUID="test-uuid" CURL_BIN="$MOCK_BIN/curl" \
    bash "$SCRIPT" > /dev/null
assert "pings success (not /fail) when sync not configured" \
    "grep -q 'test-uuid' '$PING_LOG' && ! grep -q 'test-uuid/fail' '$PING_LOG'"

echo ""
echo "-- healthcheck: /fail ping when sync fails --"
PING_LOG2="$TMPDIR_TEST/ping2.log"
cat > "$MOCK_BIN/curl" <<MOCKEOF
#!/bin/bash
echo "\$@" >> "$PING_LOG2"
MOCKEOF
cat > "$MOCK_BIN/rclone" <<'MOCKEOF'
#!/bin/bash
exit 1
MOCKEOF
chmod +x "$MOCK_BIN/curl" "$MOCK_BIN/rclone"
DB_SRC="$FAKE_DB" BACKUP_DIR="$BACKUP_ROOT" DATE="2026-06-18" DAY_OF_MONTH="18" \
    RCLONE_REMOTE="fake:bucket" RCLONE_BIN="$MOCK_BIN/rclone" \
    BACKUP_HEALTHCHECK_UUID="test-uuid" CURL_BIN="$MOCK_BIN/curl" \
    PATH="$MOCK_BIN:$PATH" bash "$SCRIPT" > /dev/null 2>&1 || true
assert "pings /fail when sync fails" "grep -q 'test-uuid/fail' '$PING_LOG2'"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
