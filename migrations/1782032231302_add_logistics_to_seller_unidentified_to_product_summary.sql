-- ============================================================================
-- Migration: add_logistics_to_seller_unidentified_to_product_summary
-- Description: Add missing column to wb_fi_report_product_summary
-- ============================================================================

BEGIN;

-- Add missing column
ALTER TABLE wb_fi_report_product_summary 
ADD COLUMN IF NOT EXISTS logistics_to_seller_unidentified NUMERIC(15,2) DEFAULT 0;

-- Add comment
COMMENT ON COLUMN wb_fi_report_product_summary.logistics_to_seller_unidentified IS 'Logistics to seller - unidentified goods (возврат неопознанного товара к продавцу)';

COMMIT;

-- Rollback:
-- BEGIN;
-- ALTER TABLE wb_fi_report_product_summary DROP COLUMN IF EXISTS logistics_to_seller_unidentified;
-- COMMIT;