-- CLOSE_THE_GAP.md Phase 4 -- Glue database holding the access-log table.
--
-- Split into its own file because Athena's StartQueryExecution accepts exactly
-- ONE statement per call; a file with several semicolon-separated statements
-- fails rather than running them in sequence. Run order is:
--   1. create_database.sql
--   2. create_table.sql
--   3. alter_table_projection.sql   (also on every later enum change)
--
-- Idempotent: IF NOT EXISTS makes a re-run a no-op.

CREATE DATABASE IF NOT EXISTS cori_data_monitoring;
