#!/bin/sh
# qBittorrent Torrent File Whitelist Script
# Filters torrents by whitelisted extensions and disables/removes unwanted files.
# All configuration is sourced from ENV_FILE (.env)
# https://github.com/trick11/qbittorrent-file-filter
# License: MIT

# Load credentials and config
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"
[ -f "$ENV_FILE" ] || { echo "[ERROR] Env file $ENV_FILE not found in $SCRIPT_DIR."; exit 1; }
. "$ENV_FILE"

log() { echo "$1" >> "$LOGFILE"; }

HASH="$1"
CATEGORY="$2"

[ -z "$HASH" ] && log "[ERROR] No hash provided." && exit 1
[ -z "$CATEGORY" ] && log "[SKIP] No category for $HASH — skipping" && exit 0

CATEGORY_LC=$(echo "$CATEGORY" | tr '[:upper:]' '[:lower:]')

# Check if category matches filter
echo "$CATEGORY_LC" | grep -Eq "(^|[|])($FILTER_CATEGORIES)($|[|])"
if [ $? -ne 0 ]; then
    log "[SKIP] $HASH is category '$CATEGORY' — not in filter ($FILTER_CATEGORIES), skipping"
    exit 0
fi

log "=== Script start for $HASH (category: $CATEGORY) ==="

# Login
/usr/bin/curl -s -c "$COOKIE_JAR" --data "username=$QB_USER&password=$QB_PASS" \
    "$QB_URL/api/v2/auth/login" > /dev/null
[ $? -ne 0 ] && log "[ERROR] Login failed" && exit 1

# Wait for metadata: up to 5 minutes (60 tries every 5s)
for i in $(seq 1 60); do
    FILES=$(/usr/bin/curl -s -b "$COOKIE_JAR" "$QB_URL/api/v2/torrents/files?hash=$HASH")
    COUNT=$(echo "$FILES" | jq 'length')
    if [ "$COUNT" -gt 0 ]; then
        log "[OK] Metadata ready after $((i * 5)) seconds"
        break
    fi
    sleep 5
done

if [ "$COUNT" -eq 0 ]; then
    log "[SKIP] No metadata after timeout — skipping $HASH"
    rm -f "$COOKIE_JAR"
    exit 0
fi

NAME=$(/usr/bin/curl -s -b "$COOKIE_JAR" "$QB_URL/api/v2/torrents/info" | \
    jq -r ".[] | select(.hash==\"$HASH\") | .name")
log "[CHECK] $NAME (category: $CATEGORY)"

# Count allowed files (whitelist logic)
ALLOWED_COUNT=$(echo "$FILES" | jq --arg re "$ALLOWED_EXTENSIONS" '
    [to_entries[] | select(.value.name | test("\\.(" + $re + ")$"; "i")) | .key] | length')
log "[DEBUG] ALLOWED_COUNT: $ALLOWED_COUNT"

if [ "$ALLOWED_COUNT" -eq 0 ]; then
    log "[DELETE] No allowed files in $NAME — removing torrent"
    /usr/bin/curl -s -b "$COOKIE_JAR" --data "hashes=$HASH&deleteFiles=true" \
        "$QB_URL/api/v2/torrents/delete"
    rm -f "$COOKIE_JAR"
    log "=== Script end for $HASH (no allowed files, deleted) ==="
    exit 0
fi

# Get space-separated indexes of non-allowed files (anything not whitelisted)
NON_ALLOWED_INDEXES=$(echo "$FILES" | jq -r --arg re "$ALLOWED_EXTENSIONS" '
  [to_entries[] | select(.value.name | test("\\.(" + $re + ")$"; "i") | not) | .key] | @sh' | tr -d "'")
log "[DEBUG] NON_ALLOWED_INDEXES: $NON_ALLOWED_INDEXES"

# Replace spaces with | for the API
NON_ALLOWED_IDS=$(echo "$NON_ALLOWED_INDEXES" | tr ' ' '|')
log "[DEBUG] NON_ALLOWED_IDS: $NON_ALLOWED_IDS"

if [ -n "$NON_ALLOWED_IDS" ]; then
    RESPONSE=$(/usr/bin/curl -s -b "$COOKIE_JAR" \
      --data "hash=$HASH&id=$NON_ALLOWED_IDS&priority=0" \
      "$QB_URL/api/v2/torrents/filePrio")
    log "[DISABLE] Non-allowed file ids disabled: $NON_ALLOWED_IDS"
    log "[DEBUG] filePrio response: $RESPONSE"
fi

rm -f "$COOKIE_JAR"
log "=== Script end for $HASH ==="
