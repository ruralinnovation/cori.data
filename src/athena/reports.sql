-- CLOSE_THE_GAP.md Phase 5 -- canned reports over s3_access_logs.
--
-- HOW TO RUN THESE: this file is a CATALOGUE, not a runnable script. It holds
-- many statements, and Athena's StartQueryExecution accepts exactly one per
-- call -- ../scripts/run-athena-query.sh will refuse the whole file by design.
-- Copy the single report you want into its own .sql file and run that:
--     ./run-athena-query.sh /tmp/my-report.sql
-- The DDL in this directory (create_database / create_table /
-- alter_table_projection / create_view_identified) IS one statement each and
-- runs directly.
--
-- Every aggregate report below groups by day (or finer) in addition to
-- whatever else it groups by. A query that collapses an entire 90-day or
-- year-to-date window into one total per bucket discards the time
-- dimension irrecoverably -- the whole point of requirement 3 was to review
-- activity over time, not to get a single number for a whole window. Day
-- granularity is the floor: anyone consuming a report can roll days up into
-- weeks or months on top of this, but no query can un-collapse a total back
-- into a timeline once it has been aggregated away. Report 6 goes further
-- and returns individual, unaggregated events with full requestdatetime
-- (hour:minute:second, not just the day), for drill-down into a specific
-- window.
--
-- Every query relies on partition projection (sourcebucket/year/month/day).
-- Date-range filters compare the concatenated (year || month || day) string
-- directly against a zero-padded 'YYYYMMDD' boundary -- a predicate purely
-- over the partition columns, which is what lets the planner prune
-- partitions before scanning. A WHERE clause built from a *derived* value
-- (e.g. from_iso8601_date(year || '-' || month || '-' || day) compared to a
-- date) does not reliably push down the same way and can fall back to
-- evaluating every partition in the projected range. The derived date is
-- still used in SELECT/GROUP BY, where it is just for display.
--
-- requester shapes seen in real production data (verified 2026-08-19
-- against cori.data.fcc's pre-existing logs):
--   '-'                                                            anonymous / unauthenticated
--   arn:aws:sts::...:assumed-role/CoriDataVendCredentials-.../...  a vended credential
--   arn:aws:sts::...:assumed-role/<other-role>/...                 some OTHER assumed-role caller
--                                                                   entirely unrelated to vending
--                                                                   (e.g. spotinst-iam-stack-.../
--                                                                   spotinst.session.... was seen
--                                                                   live in cori.data.fcc's logs)
--   <canonical user id, no arn:aws: prefix>                        an IAM user / account owner
-- The third case is why every "vended credential" report below filters
-- explicitly on the CoriDataS3ReaderRole role name rather than assuming
-- any assumed-role ARN implies vending-endpoint traffic.
--
-- CALLER CLASSIFICATION now lives in the view cori_data_monitoring.s3_access_identified
-- (see create_view_identified.sql), which adds caller_class and caller_id to
-- every row. Reports below select from the view rather than re-deriving the
-- parse, because two hand-maintained copies of that parse already drifted apart
-- (this file vs cori.data.verse/.../monitoring-s3-access/index.qmd).
--
-- METRIC NAMING -- read this before quoting any number from these reports.
-- COUNT(*) counts S3 API CALLS, not downloads. Measured 2026-09-22 over 30 days:
-- 99.31% of cori.data.fcc's anonymous GETs are HTTP 206 range reads, because
-- DuckDB/httpfs reads parquet in ranges -- 1,931,764 API calls against just
-- 13,563 distinct objects, a 142x inflation. Non-fcc buckets are unaffected
-- (0.73% range reads). So:
--   api_calls        -- S3 request count. NOT a download count. Inflated by
--                       range reads, most severely on parquet-heavy buckets.
--   distinct_objects -- COUNT(DISTINCT key). Defensible usage measure.
--   bytes_sent       -- SUM(bytessent). Defensible; real egress.
-- The concentration conclusion survives the correction: fcc is 99.87% by API
-- calls, 99.27% by distinct objects and 99.97% by bytes. Only the magnitude of
-- the request count was wrong, not the shape of the distribution.


-- 1. Requests and bytes, by bucket and by day, last 90 days.
SELECT
    sourcebucket,
    from_iso8601_date(year || '-' || month || '-' || day) AS day,
    COUNT(*)                           AS api_calls,
    COUNT_IF(httpstatus = '206')       AS range_calls,
    COUNT(DISTINCT key)                AS distinct_objects,
    SUM(TRY_CAST(bytessent AS BIGINT)) AS bytes_sent
FROM cori_data_monitoring.s3_access_logs
WHERE (year || month || day) >= date_format(current_date - interval '90' day, '%Y%m%d')
GROUP BY 1, 2
ORDER BY day DESC, bytes_sent DESC;


-- 2. By bucket, caller class, caller, and day, year-to-date.
-- caller_class/caller_id come from the view; see create_view_identified.sql for
-- the four session-name generations it has to absorb and why the epoch band is
-- {9,13} rather than {9,12}.
--
-- caller_id for a vended_tagged row is SELF-DECLARED: `caller` is an
-- unvalidated query parameter on a public, unauthenticated endpoint
-- (src/lambda/index.ts reads event.queryStringParameters.caller and only
-- sanitizes it). Present it as a usage label, never as an identity.
SELECT
    sourcebucket,
    from_iso8601_date(year || '-' || month || '-' || day) AS day,
    caller_class,
    caller_id,
    COUNT(*)                           AS api_calls,
    COUNT(DISTINCT key)                AS distinct_objects,
    SUM(TRY_CAST(bytessent AS BIGINT)) AS bytes_sent
FROM cori_data_monitoring.s3_access_identified
WHERE year = CAST(year(current_date) AS VARCHAR)
GROUP BY 1, 2, 3, 4
ORDER BY day DESC, sourcebucket, bytes_sent DESC;


-- 3. Vended-credential traffic only (excludes anonymous public reads and
--    any other assumed-role/local-credential caller), by bucket and day,
--    last 90 days.
SELECT
    sourcebucket,
    from_iso8601_date(year || '-' || month || '-' || day) AS day,
    COUNT(*)                          AS api_calls,
    SUM(TRY_CAST(bytessent AS BIGINT))  AS bytes_sent
FROM cori_data_monitoring.s3_access_identified
WHERE caller_class LIKE 'vended%'
  AND (year || month || day) >= date_format(current_date - interval '90' day, '%Y%m%d')
GROUP BY 1, 2
ORDER BY day DESC, sourcebucket;


-- 4. Anonymous public traffic, by bucket and day, last 90 days.
-- Quantifies public consumption of the world-readable buckets -- exactly
-- the measurement CLOSE_THE_GAP.md flags as the input needed to price
-- CloudTrail data events, should that ever be revisited.
SELECT
    sourcebucket,
    from_iso8601_date(year || '-' || month || '-' || day) AS day,
    COUNT(*)                          AS api_calls,
    SUM(TRY_CAST(bytessent AS BIGINT)) AS bytes_sent
FROM cori_data_monitoring.s3_access_identified
WHERE caller_class = 'anonymous_unauth'
  AND (year || month || day) >= date_format(current_date - interval '90' day, '%Y%m%d')
GROUP BY 1, 2
ORDER BY day DESC, api_calls DESC;


-- 5. Top objects by request count, per bucket and day, last 90 days.
-- To collapse this into a single overall ranking per bucket across the
-- whole window instead, sum `api_calls`/`bytes_sent` across `day` for a
-- given (sourcebucket, key) on top of this result -- that is a safe,
-- lossless roll-up. Going the other direction, from a pre-collapsed
-- ranking back to a timeline, is not possible.
SELECT
    sourcebucket,
    from_iso8601_date(year || '-' || month || '-' || day) AS day,
    key,
    COUNT(*)                          AS api_calls,
    SUM(TRY_CAST(bytessent AS BIGINT)) AS bytes_sent
FROM cori_data_monitoring.s3_access_logs
WHERE key != '-'
  AND (year || month || day) >= date_format(current_date - interval '90' day, '%Y%m%d')
GROUP BY 1, 2, 3
ORDER BY day DESC, sourcebucket, api_calls DESC;


-- 6. Raw, unaggregated events with full time-of-day precision, last 7 days.
-- For drill-down into a specific window rather than a rolled-up total.
-- requestdatetime is the raw log field, e.g. '19/Aug/2026:23:12:44 +0000';
-- parsed here into an actual timestamp for sorting/filtering.
SELECT
    sourcebucket,
    date_parse(requestdatetime, '%d/%b/%Y:%H:%i:%s +0000') AS request_time,
    requester,
    operation,
    key,
    httpstatus,
    TRY_CAST(bytessent AS BIGINT) AS bytes_sent,
    remoteip
FROM cori_data_monitoring.s3_access_logs
WHERE (year || month || day) >= date_format(current_date - interval '7' day, '%Y%m%d')
ORDER BY request_time DESC
LIMIT 500;


-- ===========================================================================
-- PROFILING THE UNAUTHENTICATED MAJORITY (reports 7-10)
--
-- Measured 2026-09-22 over 30 days: 91.98% of all GETs arrive with
-- requester = '-', i.e. no credential and no identity of any kind. No caller
-- tagging scheme can ever reach that traffic. What IS available, on every one
-- of those log lines, is remoteip, useragent, referrer and key -- all four
-- captured by the table since it was created and, until now, never consumed
-- by any report (remoteip appeared once, ungrouped, in report 6).
--
-- Read the api_calls caveat in this file's header before quoting any count
-- from these reports: on cori.data.fcc it overstates by ~142x.
-- ===========================================================================


-- 7. User-agent taxonomy for anonymous traffic, last 30 days.
-- A UA like 'duckdb/v1.5.5(windows_amd64) python/3.14 d8cdaa33fd' carries tool,
-- version, OS, arch and host-language version. This separates a researcher
-- running DuckDB against the parquet from a crawler from a browser download --
-- the actual question behind "who uses our public buckets."
--
-- The ladder is a heuristic. Before quoting any share from it, run report 7b
-- below and extend the CASE until the 'other' residual is small; publish the
-- residual alongside the shares either way.
SELECT
    sourcebucket,
    CASE
        WHEN useragent LIKE 'duckdb/%'                               THEN 'duckdb'
        WHEN useragent LIKE '%aws-cli/%'                             THEN 'aws-cli'
        WHEN useragent LIKE '%Boto3%' OR useragent LIKE '%botocore%' THEN 'boto3'
        WHEN useragent LIKE '%aws-sdk-java%'                         THEN 'aws-sdk-java'
        WHEN useragent LIKE '%aws-sdk-go%'                           THEN 'aws-sdk-go'
        WHEN useragent LIKE '%paws%' OR useragent LIKE '%libcurl%'
          OR useragent LIKE '%R (%'                                  THEN 'r-client'
        WHEN useragent LIKE '%GDAL%' OR useragent LIKE '%rasterio%'  THEN 'geospatial'
        WHEN regexp_like(useragent, '(?i)bot|spider|crawler|scrape') THEN 'crawler'
        WHEN useragent LIKE 'Mozilla/%'                              THEN 'browser'
        WHEN useragent = '-'                                         THEN 'unset'
        ELSE 'other'
    END                                                              AS ua_family,
    -- The optional 'v' matters: DuckDB reports 'duckdb/v1.5.5(...)', so a
    -- pattern requiring a digit straight after the slash returns EMPTY for the
    -- single largest anonymous client in these logs. Verified 2026-09-22.
    regexp_extract(useragent, '^([A-Za-z0-9._-]+)/v?([0-9][0-9A-Za-z.]*)', 0) AS ua_tool_version,
    COUNT(*)                            AS api_calls,
    COUNT(DISTINCT key)                 AS distinct_objects,
    COUNT(DISTINCT remoteip)            AS distinct_ips,
    SUM(TRY_CAST(bytessent AS BIGINT))  AS bytes_sent
FROM cori_data_monitoring.s3_access_identified
WHERE caller_class = 'anonymous_unauth'
  AND operation LIKE 'REST.GET.OBJECT%'
  AND (year || month || day) >= date_format(current_date - interval '30' day, '%Y%m%d')
GROUP BY 1, 2, 3
ORDER BY bytes_sent DESC;


-- 7b. Raw user-agent strings falling into 'other', last 30 days.
-- Run this FIRST and extend report 7's ladder before trusting its shares.
SELECT
    useragent,
    COUNT(*)                 AS api_calls,
    COUNT(DISTINCT remoteip) AS distinct_ips
FROM cori_data_monitoring.s3_access_identified
WHERE caller_class = 'anonymous_unauth'
  AND operation LIKE 'REST.GET.OBJECT%'
  AND (year || month || day) >= date_format(current_date - interval '30' day, '%Y%m%d')
  AND useragent <> '-'
  AND NOT regexp_like(useragent, '(?i)^duckdb/|aws-cli/|Boto3|botocore|aws-sdk-java|aws-sdk-go|paws|libcurl|GDAL|rasterio|bot|spider|crawler|scrape|^Mozilla/')
GROUP BY 1
ORDER BY api_calls DESC
LIMIT 50;


-- 8. Referrer hosts, last 90 days.
-- Programmatic clients send '-', so this is sparse by nature -- but every
-- non-null row names a third-party site linking or embedding CORI data, which
-- is the most directly reportable attribution fact anywhere in this dataset.
-- Cheapest query in the file; highest asymmetric payoff.
SELECT
    sourcebucket,
    regexp_extract(referrer, '^https?://([^/]+)', 1) AS referrer_host,
    COUNT(*)                           AS api_calls,
    COUNT(DISTINCT remoteip)           AS distinct_ips,
    COUNT(DISTINCT key)                AS distinct_objects,
    SUM(TRY_CAST(bytessent AS BIGINT)) AS bytes_sent
FROM cori_data_monitoring.s3_access_identified
WHERE caller_class = 'anonymous_unauth'
  AND referrer <> '-'
  AND (year || month || day) >= date_format(current_date - interval '90' day, '%Y%m%d')
GROUP BY 1, 2
ORDER BY api_calls DESC;


-- 9. Sessionized anonymous consumers, last 30 days.
-- Range reads make api_calls meaningless as a usage measure (see header), so
-- the unit here is a SESSION: consecutive requests from one (remoteip,
-- useragent) pair separated by less than GAP_MINUTES.
--
-- The 30-minute gap is a starting point, NOT a validated constant. Sweep it at
-- 10/30/60 and report the sensitivity rather than silently publishing one
-- number. Expect the session count to be orders of magnitude below the raw
-- api_calls figure.
--
-- Interpretation limit that cannot be resolved from logs alone: a NATed
-- institution looks like one IP, a CGNAT home user looks like many. Sessions
-- bound the truth from both sides without pinning it.
WITH e AS (
    SELECT
        sourcebucket, remoteip, useragent, key,
        date_parse(requestdatetime, '%d/%b/%Y:%H:%i:%s +0000') AS ts,
        TRY_CAST(bytessent AS BIGINT)                          AS bytes
    FROM cori_data_monitoring.s3_access_identified
    WHERE caller_class = 'anonymous_unauth'
      AND operation LIKE 'REST.GET.OBJECT%'
      AND (year || month || day) >= date_format(current_date - interval '30' day, '%Y%m%d')
),
gapped AS (
    SELECT *,
        CASE
            WHEN LAG(ts) OVER (PARTITION BY remoteip, useragent ORDER BY ts) IS NULL
              OR date_diff('minute',
                   LAG(ts) OVER (PARTITION BY remoteip, useragent ORDER BY ts), ts) >= 30
            THEN 1 ELSE 0
        END AS is_new
    FROM e
),
sessioned AS (
    SELECT *,
        SUM(is_new) OVER (PARTITION BY remoteip, useragent ORDER BY ts
                          ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) AS session_seq
    FROM gapped
)
SELECT
    sourcebucket,
    COUNT(DISTINCT remoteip || '|' || useragent || '|' || CAST(session_seq AS VARCHAR)) AS sessions,
    COUNT(DISTINCT remoteip)  AS distinct_ips,
    COUNT(DISTINCT key)       AS distinct_objects,
    SUM(bytes)                AS bytes_sent
FROM sessioned
GROUP BY 1
ORDER BY sessions DESC;


-- 10. Dataset attribution from the object key, last 30 days.
-- `key` is DOUBLY url-encoded in the access log ('release%253D2025-12-01')
-- while `requesturi` is singly encoded. Decode twice, and wrap in try() because
-- a malformed escape sequence throws rather than returning null.
--
-- key_prefix answers which dataset within a bucket is consumed; the Hive
-- partition extracts answer which vintage and geography, e.g. whether people
-- pull current releases or backfill history.
SELECT
    sourcebucket,
    split_part(COALESCE(try(url_decode(url_decode(key))), key), '/', 1) AS key_prefix,
    regexp_extract(COALESCE(try(url_decode(url_decode(key))), key), 'release=([^/]+)', 1)    AS release,
    regexp_extract(COALESCE(try(url_decode(url_decode(key))), key), 'state_usps=([^/]+)', 1) AS state_usps,
    COUNT(*)                           AS api_calls,
    COUNT(DISTINCT key)                AS distinct_objects,
    COUNT(DISTINCT remoteip)           AS distinct_ips,
    SUM(TRY_CAST(bytessent AS BIGINT)) AS bytes_sent
FROM cori_data_monitoring.s3_access_identified
WHERE caller_class = 'anonymous_unauth'
  AND operation LIKE 'REST.GET.OBJECT%'
  AND key <> '-'
  AND (year || month || day) >= date_format(current_date - interval '30' day, '%Y%m%d')
GROUP BY 1, 2, 3, 4
ORDER BY bytes_sent DESC;
