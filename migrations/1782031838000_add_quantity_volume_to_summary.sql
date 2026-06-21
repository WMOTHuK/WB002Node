-- ============================================================================
-- Migration: add_quantity_volume_to_summary
-- Description: Add quantity and volume columns to wb_fi_report_summary
-- ============================================================================

BEGIN;

-- Add columns to wb_fi_report_summary
ALTER TABLE wb_fi_report_summary 
ADD COLUMN IF NOT EXISTS quantity NUMERIC(15,3) DEFAULT 0;

ALTER TABLE wb_fi_report_summary 
ADD COLUMN IF NOT EXISTS volume NUMERIC(15,2) DEFAULT 0;

-- Add comments
COMMENT ON COLUMN wb_fi_report_summary.quantity IS 'Total quantity sold (weight: 15, scale: 3)';
COMMENT ON COLUMN wb_fi_report_summary.volume IS 'Total volume in liters (weight: 15, scale: 2)';

COMMIT;

-- Rollback:
-- BEGIN;
-- ALTER TABLE wb_fi_report_summary DROP COLUMN IF EXISTS quantity;
-- ALTER TABLE wb_fi_report_summary DROP COLUMN IF EXISTS volume;
-- COMMIT;
