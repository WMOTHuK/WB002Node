-- ============================================================================
-- Migration: change_rrd_id_and_nm_id_to_bigint
-- Description: Change rrd_id and nm_id columns from INTEGER to BIGINT
-- ============================================================================

BEGIN;

-- Изменить rrd_id
ALTER TABLE wb_fi_report_details 
ALTER COLUMN rrd_id TYPE BIGINT;

-- Изменить nm_id
ALTER TABLE wb_fi_report_details 
ALTER COLUMN nm_id TYPE BIGINT;

COMMIT;

-- Rollback:
-- BEGIN;
-- ALTER TABLE wb_fi_report_details ALTER COLUMN rrd_id TYPE INTEGER;
-- ALTER TABLE wb_fi_report_details ALTER COLUMN nm_id TYPE INTEGER;
-- COMMIT;