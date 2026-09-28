#!/usr/bin/env bash
# run-athena-query.sh — CLOSE_THE_GAP.md Phase 4 / Phase 5 query driver
#
# Submits ONE .sql file to Athena, waits for it to finish, and reports the
# scan statistics. Companion to create_database.sql / create_table.sql /
# alter_table_projection.sql in ../athena.
#
# Two arguments are passed explicitly on every call and neither is optional:
#
#   --query-execution-context Database=...
#       ../athena/*.sql qualify their objects as cori_data_monitoring.<table>,
#       but a bare SELECT in an ad-hoc report file may not, and Athena has no
#       per-account default database.
#
#   --result-configuration OutputLocation=...
#       The `primary` workgroup has an EMPTY ResultConfiguration (verified
#       2026-09-22), so Athena rejects any query that does not carry its own
#       output location. This must NOT point at cori.data.verse: that bucket is
#       world-readable, and result sets contain remoteip and full staff IAM
#       ARNs. The default below is the account's private Athena results bucket
#       (no bucket policy, owner-only).
#
# Idempotent only insofar as the SQL is: the DDL files are, reports are reads.
#
# Usage:
#   ./run-athena-query.sh --dry-run ../athena/create_table.sql
#   ./run-athena-query.sh ../athena/create_table.sql
#
# Exit codes: 0 ok, 1 usage/precondition error, 2 query failed or was cancelled.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATABASE="cori_data_monitoring"
WORKGROUP="primary"
OUTPUT_LOCATION="s3://aws-athena-query-results-312512371189-us-east-1/cori-data-monitoring/"
POLL_SECONDS=2
MAX_POLLS=900   # 30 minutes at 2s; a DDL or daily aggregate far exceeds nothing

DRY_RUN=false
if [[ "${1:-}" == "--dry-run" ]]; then
  DRY_RUN=true
  shift
fi

SQL_FILE="${1:-}"
if [[ -z "$SQL_FILE" ]]; then
  echo "[error] usage: $0 [--dry-run] <path-to-sql-file>" >&2
  exit 1
fi
if [[ ! -f "$SQL_FILE" ]]; then
  echo "[error] no such file: $SQL_FILE" >&2
  exit 1
fi

# Athena's StartQueryExecution accepts exactly ONE statement. A file holding
# several semicolon-separated statements fails with a confusing parser error
# rather than running them in order, so catch it here with a clear message.
# Comment lines are stripped first so a `;` inside a `--` comment does not
# trip the count.
STATEMENT_COUNT=$(
  sed 's/--.*$//' "$SQL_FILE" | tr -d '\n' | tr -cd ';' | wc -c | tr -d ' '
)
if [[ "$STATEMENT_COUNT" -gt 1 ]]; then
  echo "[error] $SQL_FILE contains $STATEMENT_COUNT statements; Athena accepts one." >&2
  echo "[error] split it into separate files (see ../athena/ for the pattern)." >&2
  exit 1
fi

QUERY_STRING="$(cat "$SQL_FILE")"

if [[ "$DRY_RUN" == true ]]; then
  echo "[dry-run] would submit $SQL_FILE"
  echo "[dry-run]   database        = $DATABASE"
  echo "[dry-run]   workgroup       = $WORKGROUP"
  echo "[dry-run]   output location = $OUTPUT_LOCATION"
  echo "[dry-run] statement:"
  sed 's/^/    /' "$SQL_FILE"
  exit 0
fi

echo "[running] $SQL_FILE -> $DATABASE"
QUERY_ID=$(
  aws athena start-query-execution \
    --query-string "$QUERY_STRING" \
    --work-group "$WORKGROUP" \
    --query-execution-context "Database=$DATABASE" \
    --result-configuration "OutputLocation=$OUTPUT_LOCATION" \
    --query 'QueryExecutionId' --output text
)
echo "[running] query execution id: $QUERY_ID"

polls=0
while :; do
  STATE=$(aws athena get-query-execution --query-execution-id "$QUERY_ID" \
            --query 'QueryExecution.Status.State' --output text)
  case "$STATE" in
    SUCCEEDED) break ;;
    FAILED|CANCELLED)
      REASON=$(aws athena get-query-execution --query-execution-id "$QUERY_ID" \
                 --query 'QueryExecution.Status.StateChangeReason' --output text)
      echo "[error] query $STATE: $REASON" >&2
      exit 2
      ;;
    QUEUED|RUNNING)
      polls=$((polls + 1))
      if [[ "$polls" -ge "$MAX_POLLS" ]]; then
        echo "[error] still $STATE after $((MAX_POLLS * POLL_SECONDS))s; giving up polling." >&2
        echo "[error] the query itself may still be running: $QUERY_ID" >&2
        exit 2
      fi
      sleep "$POLL_SECONDS"
      ;;
    *)
      echo "[error] unexpected state: $STATE" >&2
      exit 2
      ;;
  esac
done

# Baseline numbers the plan's verification section asks to be recorded.
aws athena get-query-execution --query-execution-id "$QUERY_ID" \
  --query 'QueryExecution.Statistics.{scanned_bytes:DataScannedInBytes,engine_ms:EngineExecutionTimeInMillis,queue_ms:QueryQueueTimeInMillis}' \
  --output json | sed 's/^/    /'

echo "[ok] $SQL_FILE"
echo "[ok] results: ${OUTPUT_LOCATION}${QUERY_ID}.csv"
