-- ============================================================================
-- Migration: add_logistics_to_seller_unidentified_column
-- Description: Add column for logistics to seller (unidentified goods)
-- ============================================================================

BEGIN;

-- Add column after logistics_to_seller_defect
ALTER TABLE wb_fi_report_summary 
ADD COLUMN logistics_to_seller_unidentified NUMERIC(15,2) DEFAULT 0;

-- Add comment
COMMENT ON COLUMN wb_fi_report_summary.logistics_to_seller_unidentified IS 'Logistics to seller - unidentified goods (возврат неопознанного товара к продавцу)';

COMMIT;

-- Rollback:
-- BEGIN;
-- ALTER TABLE wb_fi_report_summary DROP COLUMN IF EXISTS logistics_to_seller_unidentified;
-- COMMIT;