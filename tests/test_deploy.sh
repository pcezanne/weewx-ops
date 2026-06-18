#!/bin/bash
# Tests for scripts/deployWXToCloudflare.sh
# Usage: bash tests/test_deploy.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$SCRIPT_DIR/scripts/deployWXToCloudflare.sh"
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

TMPDIR_TEST=$(mktemp -d)
cleanup() { rm -rf "$TMPDIR_TEST"; }
trap cleanup EXIT

# --- Mock binaries ---
MOCK_BIN="$TMPDIR_TEST/bin"
mkdir -p "$MOCK_BIN"

printf '#!/bin/bash\nshift; exec "$@"\n'     > "$MOCK_BIN/gtimeout"; chmod +x "$MOCK_BIN/gtimeout"
printf '#!/bin/bash\necho "mock wrangler ok"\n' > "$MOCK_BIN/wrangler"; chmod +x "$MOCK_BIN/wrangler"
printf '#!/bin/bash\necho "mock rclone ok"\n'   > "$MOCK_BIN/rclone";   chmod +x "$MOCK_BIN/rclone"
printf '#!/bin/bash\necho "mock curl ok"\n'     > "$MOCK_BIN/curl";     chmod +x "$MOCK_BIN/curl"
printf '#!/bin/bash\n:\n'                       > "$MOCK_BIN/sleep";    chmod +x "$MOCK_BIN/sleep"

# --- Test environment ---
SOURCE_DIR="$TMPDIR_TEST/weewx-output"
BACKUP_DIR="$TMPDIR_TEST/backup"
ENV_FILE="$TMPDIR_TEST/weewx.env"
LOCKFILE="$TMPDIR_TEST/weewx-deploy.lock"
LOG="$TMPDIR_TEST/deploy.log"

mkdir -p "$SOURCE_DIR" "$BACKUP_DIR"
cat > "$ENV_FILE" <<'EOF'
CLOUDFLARE_API_TOKEN=fake_token
CLOUDFLARE_ACCOUNT_ID=fake_account
HEALTHCHECK_UUID=fake-uuid
WU_PASSWORD=fake_password
EOF

run_script() {
    PATH="$MOCK_BIN:$PATH" \
    SOURCE_DIR="$SOURCE_DIR" BACKUP_DIR="$BACKUP_DIR" \
    WRANGLER="$MOCK_BIN/wrangler" \
    RCLONE_BIN="$MOCK_BIN/rclone" RCLONE_CONF="$TMPDIR_TEST/rclone.conf" \
    ENV_FILE="$ENV_FILE" LOCKFILE="$LOCKFILE" LOG="$LOG" \
    bash "$SCRIPT"
}

echo "=== test_deploy.sh ==="

echo ""
echo "-- lockfile removed after successful run --"
run_script
assert "lockfile absent after success" "[ ! -f '$LOCKFILE' ]"

echo ""
echo "-- concurrent run blocked by lockfile --"
touch "$LOCKFILE"
run_script && result=0 || result=$?
assert "exits 1 when lockfile exists" "[ ${result:-0} -eq 1 ]"
rm -f "$LOCKFILE"

echo ""
echo "-- lockfile removed even when wrangler fails --"
printf '#!/bin/bash\nexit 1\n' > "$MOCK_BIN/wrangler"; chmod +x "$MOCK_BIN/wrangler"
run_script || true
assert "lockfile absent after wrangler failure" "[ ! -f '$LOCKFILE' ]"
printf '#!/bin/bash\necho "mock wrangler ok"\n' > "$MOCK_BIN/wrangler"; chmod +x "$MOCK_BIN/wrangler"

echo ""
echo "-- missing .env exits non-zero --"
ENV_FILE="/nonexistent/.env" run_script && result=0 || result=$?
assert "exits non-zero on missing .env" "[ ${result:-0} -ne 0 ]"

echo ""
echo "Results: $PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
