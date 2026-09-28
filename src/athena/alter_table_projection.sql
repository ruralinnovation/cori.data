-- CLOSE_THE_GAP.md Phase 4 -- apply the partition-projection bucket enum.
--
-- WHY THIS FILE EXISTS: create_table.sql uses CREATE EXTERNAL TABLE IF NOT
-- EXISTS, which silently no-ops once the table is deployed. Editing the enum
-- there therefore has no effect on a live table. This ALTER is what actually
-- applies it.
--
-- Preferred over DROP + CREATE even though the table is EXTERNAL (dropping
-- loses no data, since the data lives in S3): DROP + CREATE leaves a window in
-- which every report fails, and ALTER ... SET TBLPROPERTIES is idempotent.
--
-- Keep this value character-identical to 'projection.sourcebucket.values' in
-- create_table.sql. Both are ALLOWED_BUCKETS from
-- src/lib/vend-credentials-stack.ts minus 'cori.data.verse'.

ALTER TABLE cori_data_monitoring.s3_access_logs SET TBLPROPERTIES (
  'projection.sourcebucket.values' = 'cori.data.bds,cori.data.bfs,cori.data.bps,cori.data.census,cori.data.fcc,cori.data.hu,cori.data.ipeds,cori.data.patents,cori.data.pep,cori.data.qcew,cori.data.vacancy,ruraldefinitions'
);
