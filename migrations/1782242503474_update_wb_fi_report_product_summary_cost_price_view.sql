-- ============================================================================
-- Migration: update_wb_fi_report_product_summary_cost_price_view
-- Description: Filter out rows where quantity, volume, and cost_price are all zero
-- ============================================================================

BEGIN;

DROP VIEW IF EXISTS wb_fi_report_product_summary_cost_price_view CASCADE;

CREATE OR REPLACE VIEW wb_fi_report_product_summary_cost_price_view AS
SELECT 
    ps.report_id,
    g.vendorcode,
    ps.nm_id,
    ps.quantity,
    ps.volume,
    ps.cost_price
FROM wb_fi_report_product_summary ps
LEFT JOIN goods g ON g.nm_id = ps.nm_id
WHERE ps.quantity != 0 
   OR ps.volume != 0 
   OR ps.cost_price != 0
ORDER BY ps.report_id DESC, ps.nm_id;

COMMENT ON VIEW wb_fi_report_product_summary_cost_price_view IS 
'Product summary view with vendorcode, quantity, volume, cost_price (excluding zero rows)';

COMMIT;

-- Rollback:
-- BEGIN;
-- DROP VIEW IF EXISTS wb_fi_report_product_summary_cost_price_view CASCADE;
-- CREATE OR REPLACE VIEW wb_fi_report_product_summary_cost_price_view AS ... (previous version without filter);
-- COMMIT;