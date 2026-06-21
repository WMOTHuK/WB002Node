-- ============================================================================
-- Migration: update_wb_fi_report_summary_view
-- Description: Add quantity and volume to view (after report_type)
-- ============================================================================

BEGIN;

DROP VIEW IF EXISTS wb_fi_report_summary_view CASCADE;

CREATE OR REPLACE VIEW wb_fi_report_summary_view AS
SELECT 
    h.user_id,
    h.report_id,
    h.date_from,
    h.date_to,
    h.report_type,
    COALESCE(s.quantity, 0) AS quantity,
    COALESCE(s.volume, 0) AS volume,
    COALESCE(s.revenue, 0) AS revenue,
    COALESCE(s.for_pay, 0) AS for_pay,
    COALESCE(s.payback_for_return, 0) AS payback_for_return,
    COALESCE(s.logistics_total, 0) AS logistics_total,
    COALESCE(s.logistics_to_client_sale, 0) AS logistics_to_client_sale,
    COALESCE(s.logistics_to_client_cancel, 0) AS logistics_to_client_cancel,
    COALESCE(s.logistics_to_seller_callback, 0) AS logistics_to_seller_callback,
    COALESCE(s.logistics_to_seller_defect, 0) AS logistics_to_seller_defect,
    COALESCE(s.logistics_to_seller_unidentified, 0) AS logistics_to_seller_unidentified,
    COALESCE(s.logistics_from_client_cancel, 0) AS logistics_from_client_cancel,
    COALESCE(s.logistics_from_client_return, 0) AS logistics_from_client_return,
    COALESCE(s.logistics_correction, 0) AS logistics_correction,
    COALESCE(s.advertising, 0) AS advertising,
    COALESCE(s.storage, 0) AS storage,
    COALESCE(s.fines, 0) AS fines,
    COALESCE(s.acceptance, 0) AS acceptance,
    COALESCE(s.transit, 0) AS transit,
    COALESCE(s.disposal, 0) AS disposal,
    COALESCE(s.loss_compensation, 0) AS loss_compensation,
    COALESCE(s.freewill_compensation, 0) AS freewill_compensation,
    COALESCE(s.cost_price, 0) AS cost_price,
    COALESCE(s.seller_tax, 0) AS seller_tax,
    COALESCE(s.overheads, 0) AS overheads,
    COALESCE(s.report_totals, 0) AS report_totals,
    COALESCE(s.created_at, h.created_at) AS created_at,
    COALESCE(s.updated_at, h.updated_at) AS updated_at
FROM wb_fi_report_headers h
LEFT JOIN wb_fi_report_summary s ON h.user_id = s.user_id AND h.report_id = s.report_id
WHERE h.report_type = 1
ORDER BY h.report_id DESC;

COMMENT ON VIEW wb_fi_report_summary_view IS 'Report summary with quantity and volume';

COMMIT;

-- Rollback:
-- BEGIN;
-- DROP VIEW IF EXISTS wb_fi_report_summary_view CASCADE;
-- CREATE OR REPLACE VIEW wb_fi_report_summary_view AS ... (previous version without quantity/volume);
-- COMMIT;