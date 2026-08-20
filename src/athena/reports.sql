-- CLOSE_THE_GAP.md Phase 5 -- canned reports over s3_access_logs.
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


-- 1. Requests and bytes, by bucket and by day, last 90 days.
SELECT
    sourcebucket,
    from_iso8601_date(year || '-' || month || '-' || day) AS day,
    COUNT(*)                          AS requests,
    SUM(TRY_CAST(bytessent AS BIGINT)) AS bytes_sent
FROM s3_access_logs
WHERE (year || month || day) >= date_format(current_date - interval '90' day, '%Y%m%d')
GROUP BY 1, 2
ORDER BY day DESC, requests DESC;


-- 2. By bucket, caller tag, and day, year-to-date.
-- The session name is the third '/'-delimited element of the assumed-role
-- ARN (coridata-<tag>-<timestamp>); strip the 'coridata-' prefix and the
-- trailing '-<timestamp>' to recover the tag itself.
WITH vended AS (
    SELECT
        sourcebucket,
        from_iso8601_date(year || '-' || month || '-' || day)                AS day,
        regexp_extract(requester, 'assumed-role/[^/]+/(coridata-.+)$', 1)    AS session_name,
        bytessent
    FROM s3_access_logs
    WHERE year = CAST(year(current_date) AS VARCHAR)
      AND requester LIKE '%CoriDataS3ReaderRole%'
)
SELECT
    sourcebucket,
    day,
    COALESCE(
        NULLIF(regexp_extract(session_name, '^coridata-(.*)-[0-9]+$', 1), ''),
        'anonymous'
    )                                   AS caller_tag,
    COUNT(*)                           AS requests,
    SUM(TRY_CAST(bytessent AS BIGINT))  AS bytes_sent
FROM vended
GROUP BY 1, 2, 3
ORDER BY day DESC, sourcebucket, requests DESC;


-- 3. Vended-credential traffic only (excludes anonymous public reads and
--    any other assumed-role/local-credential caller), by bucket and day,
--    last 90 days.
SELECT
    sourcebucket,
    from_iso8601_date(year || '-' || month || '-' || day) AS day,
    COUNT(*)                           AS requests,
    SUM(TRY_CAST(bytessent AS BIGINT))  AS bytes_sent
FROM s3_access_logs
WHERE requester LIKE '%CoriDataS3ReaderRole%'
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
    COUNT(*)                          AS requests,
    SUM(TRY_CAST(bytessent AS BIGINT)) AS bytes_sent
FROM s3_access_logs
WHERE requester = '-'
  AND (year || month || day) >= date_format(current_date - interval '90' day, '%Y%m%d')
GROUP BY 1, 2
ORDER BY day DESC, requests DESC;


-- 5. Top objects by request count, per bucket and day, last 90 days.
-- To collapse this into a single overall ranking per bucket across the
-- whole window instead, sum `requests`/`bytes_sent` across `day` for a
-- given (sourcebucket, key) on top of this result -- that is a safe,
-- lossless roll-up. Going the other direction, from a pre-collapsed
-- ranking back to a timeline, is not possible.
SELECT
    sourcebucket,
    from_iso8601_date(year || '-' || month || '-' || day) AS day,
    key,
    COUNT(*)                          AS requests,
    SUM(TRY_CAST(bytessent AS BIGINT)) AS bytes_sent
FROM s3_access_logs
WHERE key != '-'
  AND (year || month || day) >= date_format(current_date - interval '90' day, '%Y%m%d')
GROUP BY 1, 2, 3
ORDER BY day DESC, sourcebucket, requests DESC;


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
FROM s3_access_logs
WHERE (year || month || day) >= date_format(current_date - interval '7' day, '%Y%m%d')
ORDER BY request_time DESC
LIMIT 500;
