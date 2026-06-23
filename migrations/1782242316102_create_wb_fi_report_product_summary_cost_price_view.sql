-- ============================================================================
-- Migration: create_wb_fi_report_product_summary_cost_price_view
-- Description: View for product summary with vendorcode, quantity, volume, cost_price
-- ============================================================================

BEGIN;

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
ORDER BY ps.report_id DESC, ps.nm_id;

COMMENT ON VIEW wb_fi_report_product_summary_cost_price_view IS 
'Product summary view with vendorcode, quantity, volume, cost_price';

COMMIT;

-- Rollback:
-- BEGIN;
-- DROP VIEW IF EXISTS wb_fi_report_product_summary_cost_price_view;
-- COMMIT;