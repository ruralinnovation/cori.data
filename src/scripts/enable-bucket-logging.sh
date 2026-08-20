#!/usr/bin/env bash
# enable-bucket-logging.sh — CLOSE_THE_GAP.md Phase 2
#
# Enables S3 server access logging on every ALLOWED_BUCKETS entry except
# cori.data.verse (which is the log target itself -- logging it to itself
# would create an unbounded write loop). Source list is parsed from
# vend-credentials-stack.ts rather than hardcoded, so it cannot drift from
# the credential-vending allowlist.
#
# Idempotent: re-running is a no-op on buckets already at the target config.
#
# Usage:
#   ./enable-bucket-logging.sh --dry-run
#   ./enable-bucket-logging.sh

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STACK_FILE="$SCRIPT_DIR/../lib/vend-credentials-stack.ts"
TARGET_BUCKET="cori.data.verse"
TARGET_PREFIX="logs/"

DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=true
fi

if [[ ! -f "$STACK_FILE" ]]; then
  echo "Cannot find $STACK_FILE" >&2
  exit 1
fi

# Extract the ALLOWED_BUCKETS array body and pull out quoted bucket names,
# excluding the log target itself. (Portable form -- macOS ships bash 3.2,
# so `mapfile`/`readarray` are not available.)
SOURCE_BUCKETS=()
while IFS= read -r line; do
  SOURCE_BUCKETS+=("$line")
done < <(
  awk '/^const ALLOWED_BUCKETS/,/\];/' "$STACK_FILE" \
    | grep -oE '"[a-zA-Z0-9.]+"' \
    | tr -d '"' \
    | grep -v "^${TARGET_BUCKET}\$"
)

if [[ ${#SOURCE_BUCKETS[@]} -eq 0 ]]; then
  echo "Parsed zero source buckets from $STACK_FILE -- refusing to proceed" >&2
  exit 1
fi

echo "Target: s3://${TARGET_BUCKET}/${TARGET_PREFIX}"
echo "Source buckets (${#SOURCE_BUCKETS[@]}):"
printf '  %s\n' "${SOURCE_BUCKETS[@]}"
echo

LOGGING_JSON=$(cat <<EOF
{
  "LoggingEnabled": {
    "TargetBucket": "${TARGET_BUCKET}",
    "TargetPrefix": "${TARGET_PREFIX}",
    "TargetObjectKeyFormat": {
      "PartitionedPrefix": { "PartitionDateSource": "EventTime" }
    }
  }
}
EOF
)

FAILED_BUCKETS=()

for bucket in "${SOURCE_BUCKETS[@]}"; do
  if ! aws s3api head-bucket --bucket "$bucket" >/dev/null 2>&1; then
    echo "[error]  $bucket -- bucket does not exist or is inaccessible, skipping"
    FAILED_BUCKETS+=("$bucket")
    continue
  fi

  current=$(aws s3api get-bucket-logging --bucket "$bucket" 2>/dev/null || echo '{}')
  current_target=$(echo "$current" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('LoggingEnabled',{}).get('TargetBucket',''))" 2>/dev/null || echo "")
  current_prefix=$(echo "$current" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('LoggingEnabled',{}).get('TargetPrefix',''))" 2>/dev/null || echo "")
  current_format=$(echo "$current" | python3 -c "import sys,json; d=json.load(sys.stdin); print(list(d.get('LoggingEnabled',{}).get('TargetObjectKeyFormat',{}).keys()))" 2>/dev/null || echo "[]")

  if [[ "$current_target" == "$TARGET_BUCKET" && "$current_prefix" == "$TARGET_PREFIX" && "$current_format" == "['PartitionedPrefix']" ]]; then
    echo "[skip]  $bucket -- already configured"
    continue
  fi

  if $DRY_RUN; then
    echo "[dry-run]  $bucket -- would set:"
    echo "$LOGGING_JSON" | sed 's/^/    /'
    continue
  fi

  tmpfile=$(mktemp)
  echo "$LOGGING_JSON" > "$tmpfile"
  aws s3api put-bucket-logging --bucket "$bucket" --bucket-logging-status "file://$tmpfile"
  rm -f "$tmpfile"
  echo "[applied]  $bucket"
done

if [[ ${#FAILED_BUCKETS[@]} -gt 0 ]]; then
  echo
  echo "WARNING: ${#FAILED_BUCKETS[@]} bucket(s) in ALLOWED_BUCKETS could not be configured (do not exist / inaccessible):"
  printf '  %s\n' "${FAILED_BUCKETS[@]}"
  exit 2
fi
