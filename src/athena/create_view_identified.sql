-- CLOSE_THE_GAP.md Phase 5 -- canonical caller classification over s3_access_logs.
--
-- WHY A VIEW: Athena runs one statement per execution and has no cross-statement
-- CTEs, so the alternative is pasting this classifier into every report and
-- letting the copies drift. They already drifted once: reports.sql and
-- cori.data.verse/resources/monitoring-s3-access/index.qmd shipped two DIFFERENT
-- session-name parsers that disagreed on the same rows.
--
-- The view projects every base column plus caller_class/caller_id, and keeps
-- sourcebucket/year/month/day visible so consumers can still write a predicate
-- purely over the partition columns and get partition pruning (see the header
-- of reports.sql for why that predicate shape matters).
--
-- SESSION-NAME GENERATIONS, all present in live data (measured 2026-09-22 over a
-- 30-day window):
--   coridata-anonymous-1788981200386     legacy, no fingerprint, 13-digit ms epoch
--   coridata-anon-56fbb548-1789074934    current anon, sha256(ip)[0:8], 10-digit s epoch
--   coridata-tag-<tag>-<epoch>           current tagged
--
-- EPOCH WIDTH: the band is {9,13}, NOT {9,12}. Legacy session names carry a
-- 13-digit millisecond epoch while current ones carry a 10-digit second epoch.
-- A {9,12} band silently drops every legacy row into 'vended_unparsed'.
--
-- WHY THE ANCHORED FIXED-WIDTH SUFFIX: '-[0-9]{9,13}$' is what makes the greedy
-- '(.+)' capture safe. A tag that itself ends in digits -- say
-- 'coridata-tag-run-2026-1789000000' -- parses to 'run-2026', because the anchor
-- consumes exactly the epoch. A bare '-[0-9]+$' would strip the '2026' too.
--
-- Use [0-9], never \d: Hive SERDEPROPERTIES in create_table.sql process
-- backslash escapes (hence '\\S' there) while Trino string literals do not.
-- Two escaping regimes in adjacent files is how a silent-null bug gets in.
--
-- 'other_assumed_role' MUST stay its own class. A live spotinst-iam-stack caller
-- appears in cori.data.fcc's logs (see reports.sql header); folding it into
-- local_iam would inflate staff attribution.

CREATE OR REPLACE VIEW cori_data_monitoring.s3_access_identified AS
WITH base AS (
    SELECT
        *,
        regexp_extract(requester, '^arn:aws:sts::[0-9]+:assumed-role/[^/]+/(.+)$', 1) AS session_name
    FROM cori_data_monitoring.s3_access_logs
)
SELECT
    *,
    CASE
        WHEN requester = '-'                                                   THEN 'anonymous_unauth'
        WHEN requester NOT LIKE 'arn:aws:sts::%:assumed-role/%'                THEN 'local_iam'
        WHEN requester NOT LIKE '%CoriDataS3ReaderRole%'                       THEN 'other_assumed_role'
        WHEN regexp_like(session_name, '^coridata-tag-.+-[0-9]{9,13}$')        THEN 'vended_tagged'
        WHEN regexp_like(session_name, '^coridata-anon-[0-9a-f]{8}-[0-9]{9,13}$') THEN 'vended_anon_fp'
        WHEN regexp_like(session_name, '^coridata-anonymous-[0-9]{9,13}$')     THEN 'vended_legacy_anon'
        WHEN regexp_like(session_name, '^coridata-.+-[0-9]{9,13}$')            THEN 'vended_legacy_tagged'
        ELSE 'vended_unparsed'
    END AS caller_class,
    CASE
        WHEN requester = '-' THEN 'anonymous'
        WHEN requester NOT LIKE 'arn:aws:sts::%:assumed-role/%'
            THEN COALESCE(
                   NULLIF(regexp_extract(requester, '^arn:aws:iam::[0-9]+:(?:user|role)/(?:.*/)?(.+)$', 1), ''),
                   'local_canonical_id')
        WHEN requester NOT LIKE '%CoriDataS3ReaderRole%'
            THEN COALESCE(
                   NULLIF(regexp_extract(requester, '^arn:aws:sts::[0-9]+:assumed-role/([^/]+)/', 1), ''),
                   'other_role')
        WHEN regexp_like(session_name, '^coridata-tag-.+-[0-9]{9,13}$')
            THEN regexp_extract(session_name, '^coridata-tag-(.+)-[0-9]{9,13}$', 1)
        WHEN regexp_like(session_name, '^coridata-anon-[0-9a-f]{8}-[0-9]{9,13}$')
            THEN 'ip:' || regexp_extract(session_name, '^coridata-anon-([0-9a-f]{8})-[0-9]{9,13}$', 1)
        WHEN regexp_like(session_name, '^coridata-anonymous-[0-9]{9,13}$') THEN 'anonymous'
        WHEN regexp_like(session_name, '^coridata-.+-[0-9]{9,13}$')
            THEN regexp_extract(session_name, '^coridata-(.+)-[0-9]{9,13}$', 1)
        ELSE COALESCE(NULLIF(session_name, ''), 'unknown')
    END AS caller_id
FROM base;
