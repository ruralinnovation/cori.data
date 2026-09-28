# S3 Usage Reports

``` r

library(DBI)
library(dplyr)
library(knitr)
```

Every CORI data bucket writes S3 server access logs to
`s3://cori.data.verse/logs/`. This vignette runs the ten canned reports
in `src/athena/reports.sql` against those logs and records what each one
found.

The following code chunks require live AWS credentials with Athena, Glue
and S3 permissions, which vended credentials deliberately do not carry.
The findings below each chunk are from a real run on 2026-09-23.

### Two things to know before reading any number

**`api_calls` is not a download count.** DuckDB and similar clients read
parquet files in HTTP 206 range requests, so one logical download
becomes hundreds of API calls. Over the 30 days measured, 1,918,454 of
`cori.data.fcc`’s 2,049,798 calls were range reads. Use
`distinct_objects` and `bytes_sent` as usage measures.

**Caller identity comes from a view, not from tags.** All classification
lives in `cori_data_monitoring.s3_access_identified`, which resolves
four generations of vended session-name format into `caller_class` and
`caller_id`. Keeping it in one place is deliberate: this document and
`reports.sql` previously carried two hand-written parsers that
disagreed.

Every report below uses the same 30-day window so the numbers are
comparable across reports. Report 6 is the one exception and says so.

``` r

con <- dbConnect(
  noctua::athena(),
  schema_name    = "cori_data_monitoring",
  s3_staging_dir = Sys.getenv(
    "CORI_ATHENA_STAGING",
    "s3://aws-athena-query-results-312512371189-us-east-1/cori-data-monitoring/"
  )
)
```

The `s3_staging_dir` must not be a public bucket — result sets contain
source IPs and full staff IAM ARNs. The default above is the account’s
private Athena results bucket.

### Report 1 — Requests and bytes, by bucket and day

``` r

report_01 <- dbGetQuery(con, "
  SELECT
      sourcebucket,
      from_iso8601_date(year || '-' || month || '-' || day) AS day,
      COUNT(*)                           AS api_calls,
      COUNT_IF(httpstatus = '206')       AS range_calls,
      COUNT(DISTINCT key)                AS distinct_objects,
      SUM(TRY_CAST(bytessent AS BIGINT)) AS bytes_sent
  FROM cori_data_monitoring.s3_access_logs
  WHERE (year || month || day) >= date_format(current_date - interval '30' day, '%Y%m%d')
  GROUP BY 1, 2
  ORDER BY day DESC, bytes_sent DESC
")
```

This is the baseline shape of all traffic: one row per bucket per day,
with no filtering by who made the request. The `range_calls` column
exists purely so the inflation is visible rather than hidden inside
`api_calls`.

``` r

report_01 |>
  group_by(sourcebucket) |>
  summarise(
    api_calls   = sum(api_calls),
    range_calls = sum(range_calls),
    objects     = sum(distinct_objects),
    gb          = round(sum(bytes_sent, na.rm = TRUE) / 1e9, 2),
    days        = n(),
    .groups     = "drop"
  ) |>
  arrange(desc(gb)) |>
  kable(caption = "30-day totals by bucket")
```

Across 31 days and 12 buckets it returned 312 rows totalling 2,261,151
API calls and 868 GB. The distribution is extremely lopsided:
`cori.data.fcc` alone accounts for 2,049,798 calls and 843 GB, which is
97% of bytes served. Everything else is small — `cori.data.bds` and
`cori.data.qcew` are next at roughly 12 GB each, and the remaining eight
buckets together move under 1 GB.

The range-read column shows where the inflation lives. For
`cori.data.fcc`, 1,918,454 of 2,049,798 calls are 206s against just
29,857 distinct objects. For `cori.data.census`, `ruraldefinitions`,
`patents` and `vacancy` the range count is zero, so their call counts
are honest download counts.

`cori.data.bfs` and `cori.data.hu` appear with a single day each. Server
access logging was switched on for those two buckets on 2026-09-22 —
they had been silently unmonitored, which is why they produced no log
objects at all before that date.

### Report 2 — By caller class and caller

``` r

report_02 <- dbGetQuery(con, "
  SELECT
      sourcebucket,
      from_iso8601_date(year || '-' || month || '-' || day) AS day,
      caller_class,
      caller_id,
      COUNT(*)                           AS api_calls,
      COUNT(DISTINCT key)                AS distinct_objects,
      SUM(TRY_CAST(bytessent AS BIGINT)) AS bytes_sent
  FROM cori_data_monitoring.s3_access_identified
  WHERE (year || month || day) >= date_format(current_date - interval '30' day, '%Y%m%d')
  GROUP BY 1, 2, 3, 4
  ORDER BY day DESC, sourcebucket, bytes_sent DESC
")
```

This is the only report that answers “who,” and it is the reason the
`s3_access_identified` view exists. `caller_class` separates four things
that earlier versions of this analysis collapsed into one bucket
labelled “anonymous.”

``` r

report_02 |>
  group_by(caller_class) |>
  summarise(
    api_calls = sum(api_calls),
    callers   = n_distinct(caller_id),
    gb        = round(sum(bytes_sent, na.rm = TRUE) / 1e9, 2),
    .groups   = "drop"
  ) |>
  arrange(desc(api_calls)) |>
  kable(caption = "30-day traffic by caller class")
```

Over the window measured that returned 2,049,987 calls and 843 GB for
`anonymous_unauth`, 185,471 calls and 24.7 GB for `local_iam` across
four identities, 25,424 calls for `other_assumed_role` across three, and
269 calls totalling 30 MB for the two vended classes combined.

The headline is the ratio. Vended credentials — the mechanism built
specifically to identify callers — account for 269 of 2.26 million
calls, about one in 8,400. Meanwhile 91% of calls and 97% of bytes
arrive with `requester = '-'`: no credential, no identity, nothing a
tagging scheme can ever reach.

`local_iam` resolves to four named staff identities, which need no
tagging mechanism because the IAM ARN already names them exactly.
Between them they account for essentially all internal traffic,
concentrated in two people.

`other_assumed_role` is worth keeping separate rather than folding into
staff: it is entirely infrastructure — a Spotinst role and an AWS Config
role polling bucket metadata. Counting those as staff activity would
overstate internal use by about 25,000 calls.

### Report 3 — Vended-credential traffic only

``` r

report_03 <- dbGetQuery(con, "
  SELECT
      sourcebucket,
      from_iso8601_date(year || '-' || month || '-' || day) AS day,
      COUNT(*)                           AS api_calls,
      SUM(TRY_CAST(bytessent AS BIGINT)) AS bytes_sent
  FROM cori_data_monitoring.s3_access_identified
  WHERE caller_class LIKE 'vended%'
    AND (year || month || day) >= date_format(current_date - interval '30' day, '%Y%m%d')
  GROUP BY 1, 2
  ORDER BY day DESC, sourcebucket
")
```

Isolates traffic that came through the credential-vending endpoint. The
filter is on `caller_class`, not on a substring match against the
requester ARN, so it cannot accidentally sweep in unrelated assumed
roles.

``` r

report_03 |>
  arrange(desc(day), sourcebucket) |>
  mutate(mb = round(bytes_sent / 1e6, 2)) |>
  select(sourcebucket, day, api_calls, mb) |>
  kable(caption = "All vended-credential traffic, 30 days")
```

Nine rows. Thirty days of vending activity is 269 API calls and 30 MB
across three buckets (`qcew`, `pep`, `bps`) on six distinct days. Two
anonymous fingerprints and one legacy session account for all of it.

That number is the single most useful result in this vignette, because
of how small it is. The vending endpoint works correctly and is almost
completely unused. Any proposal to improve caller attribution by
enriching vended session names is optimising the 0.01% — and the raw
`remoteip` on the same log line already distinguishes these callers
anyway.

### Report 4 — Anonymous public traffic

``` r

report_04 <- dbGetQuery(con, "
  SELECT
      sourcebucket,
      from_iso8601_date(year || '-' || month || '-' || day) AS day,
      COUNT(*)                          AS api_calls,
      SUM(TRY_CAST(bytessent AS BIGINT)) AS bytes_sent
  FROM cori_data_monitoring.s3_access_identified
  WHERE caller_class = 'anonymous_unauth'
    AND (year || month || day) >= date_format(current_date - interval '30' day, '%Y%m%d')
  GROUP BY 1, 2
  ORDER BY day DESC, api_calls DESC
")
```

The complement of report 3: everything arriving with no credential at
all. This is public consumption of the world-readable buckets.

``` r

report_04 |>
  group_by(sourcebucket) |>
  summarise(
    api_calls = sum(api_calls),
    gb        = round(sum(bytes_sent, na.rm = TRUE) / 1e9, 2),
    days      = n(),
    .groups   = "drop"
  ) |>
  arrange(desc(gb)) |>
  kable(caption = "Anonymous public traffic by bucket")
```

189 rows, 2,049,987 API calls, 843 GB across 10 buckets and 29 days.
Daily volume on `cori.data.fcc` is volatile — 121,859 calls one day
against 54,745 the next — which is consistent with a small number of
large, bursty jobs rather than steady background traffic.

This report is where the request-count caveat bites hardest. Read alone
it suggests two million downloads. Reports 9 and 10 show the same
traffic is roughly 2,200 sessions pulling 13,563 distinct objects.

### Report 5 — Top objects

``` r

report_05 <- dbGetQuery(con, "
  SELECT
      sourcebucket,
      from_iso8601_date(year || '-' || month || '-' || day) AS day,
      key,
      COUNT(*)                          AS api_calls,
      SUM(TRY_CAST(bytessent AS BIGINT)) AS bytes_sent
  FROM cori_data_monitoring.s3_access_logs
  WHERE key != '-'
    AND (year || month || day) >= date_format(current_date - interval '30' day, '%Y%m%d')
  GROUP BY 1, 2, 3
  ORDER BY day DESC, sourcebucket, api_calls DESC
")
```

Object-level detail, one row per bucket, day and key. Useful for finding
which specific files drive load.

``` r

report_05 |>
  group_by(sourcebucket, key) |>
  summarise(
    api_calls = sum(api_calls),
    gb        = round(sum(bytes_sent, na.rm = TRUE) / 1e9, 2),
    .groups   = "drop"
  ) |>
  slice_max(api_calls, n = 10) |>
  kable(caption = "Ten most-requested objects over 30 days")
```

31,885 rows covering 14,206 distinct keys. `cori.data.fcc` contributes
13,823 of those keys and 2,035,498 calls — so the concentration seen at
bucket level holds at object level too.

The top objects are all National Broadband Map parquet partitions, and
the pattern is unmistakable: a single file such as
`nbm_raw/release%253D2025-12-01/state_usps%253DCA/technology%253D71/data_0.parquet`
drew 4,138 API calls in one day for 1.87 GB. That is one file being
range-read thousands of times, not thousands of downloads.

Note the keys are doubly URL-encoded here (`%253D` rather than `=`).
Report 10 decodes them.

### Report 6 — Raw event drill-down

``` r

report_06 <- dbGetQuery(con, "
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
  WHERE (year || month || day) >= date_format(current_date - interval '1' day, '%Y%m%d')
  ORDER BY request_time DESC
  LIMIT 500
")
```

Unaggregated events with full timestamp precision, for investigating a
specific incident or window. **This is the one report on a 1-day
window**, not 30 days — with `LIMIT 500` a wider window returns the same
500 most recent rows while scanning thirty times the data.

``` r

report_06 |>
  count(operation, httpstatus, name = "events") |>
  arrange(desc(events)) |>
  kable(caption = "Most recent 500 events, by operation and status")
```

The 500 most recent events are dominated by infrastructure rather than
data access: 252 are `REST.GET.LOCATION` and the rest are
`REST.GET.ACL`, `REST.GET.BUCKETPOLICY`, `REST.GET.CORS` and
`REST.GET.LIFECYCLE`, almost all from the Spotinst role enumerating
bucket configuration on a schedule.

Status codes are worth watching here: 418 of 500 were 200, but 68 were
404 and 14 were 403. A steady trickle of 404s and 403s from automated
pollers is normal, but this is the report to check first if that ratio
shifts.

Because the operations are metadata reads, not object reads, note that
this report has no `operation LIKE 'REST.GET.OBJECT%'` filter — it
deliberately shows everything.

### Report 7 — User-agent taxonomy

``` r

report_07 <- dbGetQuery(con, "
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
  ORDER BY bytes_sent DESC
")
```

Since anonymous traffic carries no credential, the user-agent string is
the best available signal about who the consumer is.

`useragent` is an HTTP request header. Every client names itself in it,
by convention as `Name/Version` — a browser sends
`Mozilla/5.0 (Macintosh...)`, the AWS CLI sends `aws-cli/2.x`, DuckDB
sends `duckdb/v1.5.5(linux_amd64) python/3.11`. S3 copies whatever the
client sent into the access log verbatim. It is free text:
self-reported, unverified and trivially spoofable, so treat it as
evidence rather than proof. Most clients report honestly because they
have no reason not to.

``` r

report_07 |>
  group_by(ua_family) |>
  summarise(
    api_calls = sum(api_calls),
    objects   = sum(distinct_objects),
    ips       = sum(distinct_ips),
    gb        = round(sum(bytes_sent, na.rm = TRUE) / 1e9, 1),
    .groups   = "drop"
  ) |>
  mutate(calls_per_object = round(api_calls / objects, 1)) |>
  arrange(desc(gb)) |>
  kable(caption = "Anonymous traffic by client family")
```

62 rows collapse to six families. DuckDB dominates at 1,902,545 calls
and 697 GB, followed by boto3 at 14,688 calls and 113 GB, crawlers at
20.5 GB, the unclassified residual at 11.9 GB, browsers at 1.2 GB, and R
clients with 2,319 calls but negligible bytes.

The contrast between the top two rows is the most informative thing
here. DuckDB made 1.9 million calls against 2,888 objects — 659 calls
per object, pure range-reading. Boto3 made 14,688 calls against 13,013
objects, almost exactly one call per object: whole-file downloads. Both
are legitimate; they are simply different access patterns, and only one
of them inflates counts.

`ua_tool_version` resolves to specific builds, which is more actionable
than the family alone — `duckdb/v1.5.5` dominates, with a tail of
`v1.5.3`, and the raw strings carry the host Python version too.

One implementation note: this regex originally required a digit
immediately after the slash, which silently returned empty for every
DuckDB row, because DuckDB reports `duckdb/v1.5.5`. The `v?` is
load-bearing.

### Report 7b — Unclassified user agents

``` r

report_07b <- dbGetQuery(con, "
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
  LIMIT 50
")
```

The honesty check on report 7. Any taxonomy built from `LIKE` patterns
is a guess, and this shows what the guess missed. Run it before quoting
report 7’s shares.

``` r

report_07b |>
  mutate(calls_per_ip = round(api_calls / distinct_ips, 1)) |>
  arrange(desc(api_calls)) |>
  kable(caption = "User agents the taxonomy does not classify")
```

22 distinct strings, 2,273 API calls — about 0.1% of anonymous traffic,
so report 7’s shares are trustworthy. But the residual contains the most
interesting names in the whole dataset:

- `RuralConnectivityBEAD/1.0` and `RuralConnectivityWireModel/1.0` —
  named, purpose-built third-party software. Someone wrote a tool
  against CORI data and named it after what it does. Drilled into below.
- `RStudio Desktop (2026.1.1.403); R (4.5.2 aarch64-apple-darwin20)` — R
  users working interactively, 335 and 315 calls, one IP each. Report
  7’s `r-client` branch matches `paws`, `libcurl` and `R (`, but
  RStudio’s string puts the `R (` token after a semicolon in a way that
  branch misses, so R usage is understated there.
- `PychSystem/0.1 (homes-bdc)` — another named tool, 63 calls from one
  IP.
- `curl` accounts for 482 calls from 343 distinct IPs across three
  versions. That is a completely different shape from the others: many
  people each running a one-off command, rather than one program running
  repeatedly.

The ladder in report 7 should gain an `RStudio` branch and a `curl`
branch before its family shares are published.

#### Drilling into a named client

A name in the residual is worth following up, because it is the only
place in these logs where a consumer volunteers who they are. This query
characterises the whole `RuralConnectivity` family.

``` r

rural_connectivity <- dbGetQuery(con, "
  SELECT
      useragent,
      remoteip,
      split_part(COALESCE(try(url_decode(url_decode(key))), key), '/', 1) AS key_prefix,
      COUNT(*)                            AS api_calls,
      COUNT(DISTINCT key)                 AS distinct_objects,
      MIN(from_iso8601_date(year || '-' || month || '-' || day)) AS first_day,
      MAX(from_iso8601_date(year || '-' || month || '-' || day)) AS last_day,
      SUM(TRY_CAST(bytessent AS BIGINT))  AS bytes_sent
  FROM cori_data_monitoring.s3_access_identified
  WHERE useragent LIKE 'RuralConnectivity%'
    AND (year || month || day) >= date_format(current_date - interval '30' day, '%Y%m%d')
  GROUP BY 1, 2, 3
  ORDER BY api_calls DESC
")
```

``` r

rural_connectivity |>
  group_by(useragent, key_prefix) |>
  summarise(
    api_calls = sum(api_calls),
    objects   = sum(distinct_objects),
    ips       = n_distinct(remoteip),
    gb        = round(sum(bytes_sent, na.rm = TRUE) / 1e9, 2),
    first_day = min(first_day),
    last_day  = max(last_day),
    .groups   = "drop"
  ) |>
  mutate(calls_per_object = round(api_calls / objects, 2)) |>
  arrange(desc(api_calls)) |>
  kable(caption = "The RuralConnectivity client family")
```

``` r

rural_connectivity |>
  group_by(remoteip) |>
  summarise(
    tools     = n_distinct(useragent),
    api_calls = sum(api_calls),
    gb        = round(sum(bytes_sent, na.rm = TRUE) / 1e9, 2),
    .groups   = "drop"
  ) |>
  arrange(desc(api_calls)) |>
  kable(caption = "Which hosts ran which tools")
```

There are three variants, not two — a bare `RuralConnectivity/1.0` also
appears. Together they made 787 calls for 3.35 GB, entirely against
`cori.data.fcc`, hitting the `nbm_raw` and `nbm_block-D25` prefixes.

Three things stand out.

The access pattern is whole-file downloads: 424 calls for 424 distinct
objects, a ratio of almost exactly 1.0. Compare that with DuckDB’s 659
calls per object in report 7. Both are legitimate, but only one inflates
request counts, and this is a good illustration of why
`distinct_objects` is the honest measure.

It is one operator, not three. One host ran all three tools and another
ran two; a third host sits in the same /24 as the first. The shared
naming root is therefore a family of related programs from a single
party, not independent consumers who happened to pick similar names.

It was a single day. Every request landed on 2026-09-21, with nothing
before or after in thirty days of logs. So this is a one-off batch pull
or a development run, not an established recurring pipeline — which is
worth knowing before treating it as a stable downstream dependency.

The names line up with the data: `nbm_raw` is National Broadband Map
data, BEAD is the federal Broadband Equity, Access and Deployment
program, and “WireModel” reads like wireline modelling. The plausible
reading is someone building BEAD-related broadband analysis on the FCC
data CORI republishes.

Two limits worth stating. The user agent is unverified free text, so the
name is a claim rather than an identity. And logs cannot tell you who
the operator is — that needs ASN or reverse-DNS lookup on the IPs, which
Athena cannot do.

### Report 8 — Referrer hosts

``` r

report_08 <- dbGetQuery(con, "
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
    AND (year || month || day) >= date_format(current_date - interval '30' day, '%Y%m%d')
  GROUP BY 1, 2
  ORDER BY api_calls DESC
")
```

The `referrer` field is populated only when a browser follows a link, so
it is sparse by construction — programmatic clients send `-`. It is
included because every non-null row names an actual referring site,
which nothing else in these logs provides.

``` r

report_08 |>
  arrange(desc(api_calls)) |>
  mutate(mb = round(bytes_sent / 1e6, 2)) |>
  select(sourcebucket, referrer_host, api_calls, distinct_ips,
         distinct_objects, mb) |>
  kable(caption = "Referring hosts for anonymous traffic")
```

14 rows, and the sparsity is as expected. The result worth noting is
`www.google.com` referring 65 requests from 64 distinct IPs to
`cori.data.fcc`: people are finding CORI data files through Google
search and downloading them directly. Sixty-four different people in
thirty days is small in volume but it is real organic discovery,
invisible in every other report.

Most remaining rows are `us-east-1.console.aws.amazon.com` — staff
clicking through the AWS console, not external interest. One row shows
`ruraldefinitions.s3.us-east-1.amazonaws.com` referring to itself, which
is a bucket-hosted page linking to its own objects.

### Report 9 — Sessionized anonymous consumers

``` r

report_09 <- dbGetQuery(con, "
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
  ORDER BY sessions DESC
")
```

This is the report that actually answers the question in the title.
Because range reads make `api_calls` meaningless as a measure of use,
the unit here is a session: consecutive requests from one
`(remoteip, useragent)` pair separated by less than thirty minutes.

``` r

report_09 |>
  mutate(
    gb                 = round(bytes_sent / 1e9, 2),
    sessions_per_ip    = round(sessions / distinct_ips, 2)
  ) |>
  select(sourcebucket, sessions, distinct_ips, sessions_per_ip,
         distinct_objects, gb) |>
  arrange(desc(sessions)) |>
  kable(caption = "Anonymous sessions over 30 days")
```

Six rows. `cori.data.fcc` carries 2,194 sessions from 1,033 IPs against
13,563 distinct objects and 843 GB; `ruraldefinitions` 138 sessions from
129 IPs; `cori.data.qcew` 96 from 12; `cori.data.pep` 81 from 29;
`cori.data.bds` 48 from 15; `cori.data.bps` a single session.

2,558 sessions from 1,219 distinct IP addresses over thirty days. Set
that against report 4’s 2,049,987 API calls: the same traffic, measured
in a unit that means something, is roughly three orders of magnitude
smaller.

The per-bucket shapes differ in a way worth noticing. `ruraldefinitions`
has 138 sessions from 129 IPs — almost one session each, i.e. many
different people each visiting once. `cori.data.qcew` has 96 sessions
from just 12 IPs — a few consumers returning repeatedly. Those are
different audiences and imply different things about how the data is
used.

Two caveats that cannot be resolved from logs alone. The thirty-minute
gap is a starting point, not a validated constant; sweep it at 10, 30
and 60 minutes and report the sensitivity rather than publishing one
number. And a NATed institution appears as one IP while a CGNAT home
user appears as several, so sessions bound the truth from both sides
without pinning it.

### Report 10 — Dataset attribution from the object key

``` r

report_10 <- dbGetQuery(con, "
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
  ORDER BY bytes_sent DESC
")
```

Translates object keys into dataset terms. Keys in the access log are
doubly URL-encoded — `release%253D2025-12-01` rather than
`release=2025-12-01` — so `url_decode` is applied twice, wrapped in
[`try()`](https://rdrr.io/r/base/try.html) because a malformed escape
sequence throws rather than returning null. Once decoded, the Hive
partition values name the vintage and geography directly.

``` r

report_10 |>
  group_by(sourcebucket, key_prefix) |>
  summarise(
    api_calls = sum(api_calls),
    objects   = sum(distinct_objects),
    gb        = round(sum(bytes_sent, na.rm = TRUE) / 1e9, 2),
    .groups   = "drop"
  ) |>
  slice_max(gb, n = 10) |>
  kable(caption = "Consumption by dataset prefix")
```

``` r

report_10 |>
  filter(!is.na(state_usps), state_usps != "") |>
  group_by(state_usps) |>
  summarise(
    api_calls = sum(api_calls),
    ips       = sum(distinct_ips),
    gb        = round(sum(bytes_sent, na.rm = TRUE) / 1e9, 1),
    .groups   = "drop"
  ) |>
  slice_max(gb, n = 10) |>
  kable(caption = "Top states by bytes served")
```

487 rows. `nbm_raw` under `cori.data.fcc` is 1,928,557 calls and 833 GB,
dwarfing everything else; the next largest prefixes are
`Staff estimates (source)` at 6.5 GB and `source` at 2.4 GB.

Two things stand out. Consumption is almost entirely of a single
release, `2025-12-01` — the current one. People are pulling current
data, not backfilling history, which is a useful input to any decision
about how long to retain old vintages.

And demand is strongly geographic: Texas leads at 371,597 calls and 171
GB, followed by California at 154 GB, Florida at 106 GB and Illinois at
49 GB. The per-state IP counts are small — 17 for Texas, 12 for
California — so this is a modest number of consumers pulling large
state-level extracts, not broad diffuse interest.

### What these reports establish

Three findings hold across the set.

The consumers are external and anonymous. 91% of calls and 97% of bytes
carry no credential. The identification mechanism built for this purpose
— vended credentials — covers 269 calls in thirty days, one in 8,400.

The real audience is small and legible. Roughly 2,600 sessions from
1,200 IP addresses, pulling 13,663 distinct objects, overwhelmingly
current-release National Broadband Map extracts for a handful of large
states. Named clients in the user-agent residual show at least two
purpose-built third-party tools and a steady trickle of R and curl
users.

Request counts mislead by two to three orders of magnitude. Any
statement of the form “two million requests” describes range-read
behaviour, not demand. Reports 9 and 10 are the ones to quote.

``` r

dbDisconnect(con)
```
