-- CLOSE_THE_GAP.md Phase 4 -- Athena table over S3 server access logs.
--
-- The 27-field layout and field order below were taken directly from AWS's
-- official S3 server access log format documentation
-- (https://docs.aws.amazon.com/AmazonS3/latest/userguide/LogFormat.html,
-- fetched and field-verified against a live sample record on 2026-08-19),
-- not transcribed from a third-party source. AWS documents this format as
-- "extensible" -- older log lines may be missing the three most recently
-- added trailing fields (access point ARN, aclRequired, source region).
-- The regex below makes those three fields optional (trailing
-- `(?: (\S+))?` groups) so a short/older line still matches instead of the
-- whole record nulling out, which is how Hive's RegexSerDe behaves on any
-- line that doesn't match the full pattern.
--
-- All columns are typed STRING because RegexSerDe cannot type its own
-- output; numeric columns (bytessent, httpstatus, etc.) are cast at query
-- time in reports.sql via TRY_CAST, which also absorbs the literal "-"
-- S3 writes for "not applicable."

-- INVARIANT: 'projection.sourcebucket.values' below is ALLOWED_BUCKETS from
-- src/lib/vend-credentials-stack.ts MINUS 'cori.data.verse' (which is the log
-- DESTINATION, not a logged source). This is the same rule
-- src/scripts/enable-bucket-logging.sh:40-43 implements when it decides which
-- buckets to turn logging on for. The enum has drifted from that list twice --
-- cori.data.bfs and cori.data.hu were added to ALLOWED_BUCKETS and never here,
-- so their logs landed in a prefix the table could not project. When you add a
-- bucket there, add it here, and re-run alter_table_projection.sql.
--
-- NOTE: CREATE EXTERNAL TABLE IF NOT EXISTS silently no-ops against an existing
-- table, so editing the enum in this file changes NOTHING on a deployed table.
-- alter_table_projection.sql is what actually applies a changed enum.

CREATE EXTERNAL TABLE IF NOT EXISTS cori_data_monitoring.s3_access_logs (
  bucketowner       STRING,
  bucket_name       STRING,
  requestdatetime   STRING,
  remoteip          STRING,
  requester         STRING,
  requestid         STRING,
  operation         STRING,
  key               STRING,
  requesturi        STRING,
  httpstatus        STRING,
  errorcode         STRING,
  bytessent         STRING,
  objectsize        STRING,
  totaltime         STRING,
  turnaroundtime    STRING,
  referrer          STRING,
  useragent         STRING,
  versionid         STRING,
  hostid            STRING,
  signatureversion  STRING,
  ciphersuite       STRING,
  authtype          STRING,
  hostheader        STRING,
  tlsversion        STRING,
  accesspointarn    STRING,
  aclrequired       STRING,
  sourceregion      STRING
)
PARTITIONED BY (
  sourcebucket STRING,
  year         STRING,
  month        STRING,
  day          STRING
)
ROW FORMAT SERDE 'org.apache.hadoop.hive.serde2.RegexSerDe'
WITH SERDEPROPERTIES (
  'input.regex' = '^(\\S+) (\\S+) \\[(.*?)\\] (\\S+) (\\S+) (\\S+) (\\S+) (\\S+) "([^"]*)" (\\S+) (\\S+) (\\S+) (\\S+) (\\S+) (\\S+) "([^"]*)" "([^"]*)" (\\S+) (\\S+) (\\S+) (\\S+) (\\S+) (\\S+) (\\S+)(?: (\\S+))?(?: (\\S+))?(?: (\\S+))?$'
)
STORED AS TEXTFILE
LOCATION 's3://cori.data.verse/logs/312512371189/us-east-1/'
TBLPROPERTIES (
  'projection.enabled'             = 'true',
  'projection.sourcebucket.type'   = 'enum',
  'projection.sourcebucket.values' = 'cori.data.bds,cori.data.bfs,cori.data.bps,cori.data.census,cori.data.fcc,cori.data.hu,cori.data.ipeds,cori.data.patents,cori.data.pep,cori.data.qcew,cori.data.vacancy,ruraldefinitions',
  'projection.year.type'           = 'integer',
  'projection.year.range'          = '2026,2032',
  'projection.month.type'          = 'integer',
  'projection.month.range'         = '1,12',
  'projection.month.digits'        = '2',
  'projection.day.type'            = 'integer',
  'projection.day.range'           = '1,31',
  'projection.day.digits'          = '2',
  'storage.location.template'      = 's3://cori.data.verse/logs/312512371189/us-east-1/${sourcebucket}/${year}/${month}/${day}'
);
