-- ============================================================================
-- Migration: update_wb_fi_report_product_summary_view
-- Description: Support multiple report_ids (via ANY operator)
-- ============================================================================

BEGIN;

DROP VIEW IF EXISTS wb_fi_report_product_summary_view CASCADE;

CREATE OR REPLACE VIEW wb_fi_report_product_summary_view AS
SELECT 
    ps.user_id,
    ps.report_id,
    ps.nm_id,
    g.vendorcode,
    g.title AS product_title,
    ps.quantity,
    ps.volume,
    ps.revenue,
    ps.for_pay,
    ps.payback_for_return,
    ps.logistics_total,
    ps.logistics_to_client_sale,
    ps.logistics_to_client_cancel,
    ps.logistics_to_seller_callback,
    ps.logistics_to_seller_defect,
    ps.logistics_to_seller_unidentified,
    ps.logistics_from_client_cancel,
    ps.logistics_from_client_return,
    ps.logistics_correction,
    ps.advertising,
    ps.storage,
    ps.fines,
    ps.acceptance,
    ps.transit,
    ps.disposal,
    ps.loss_compensation,
    ps.freewill_compensation,
    ps.cost_price,
    ps.seller_tax,
    ps.overheads,
    ps.report_totals,
    ps.created_at,
    ps.updated_at
FROM wb_fi_report_product_summary ps
LEFT JOIN goods g ON g.nm_id = ps.nm_id
WHERE ps.report_id IN (
    SELECT report_id 
    FROM wb_fi_report_headers 
    WHERE report_type = 1
)
ORDER BY ps.report_id DESC, ps.nm_id;

COMMENT ON VIEW wb_fi_report_product_summary_view IS 
    'Product-level report summary with vendorcode and product title from goods';

COMMIT;