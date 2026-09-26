-- ============================================================================
-- Migration: add_sales_correction_to_views
-- Description: Add sales_correction column to product summary and summary views
-- ============================================================================

BEGIN;

-- ============================================================================
-- 1. Обновить wb_fi_report_summary_view
-- ============================================================================

DROP VIEW IF EXISTS wb_fi_report_summary_view CASCADE;

CREATE VIEW wb_fi_report_summary_view AS
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
    COALESCE(s.sales_correction, 0) AS sales_correction,
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

COMMENT ON VIEW wb_fi_report_summary_view IS 'Report summary with quantity, volume and sales_correction';

-- ============================================================================
-- 2. Обновить wb_fi_report_product_summary_view
-- ============================================================================

DROP VIEW IF EXISTS wb_fi_report_product_summary_view CASCADE;

CREATE VIEW wb_fi_report_product_summary_view AS
SELECT 
    ps.report_id,
    gg.goods_type_id,
    COALESCE(gt.name_ru, 'Без типа') AS goods_type_name,
    g.goods_grp_id,
    COALESCE(gg.name_ru, 'Без группы') AS goods_grp_name,
    g.title,
    g.vendorcode,
    ps.quantity,
    ps.volume,
    ps.revenue,
    ps.for_pay,
    ps.sales_correction,
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
    ps.report_totals
FROM wb_fi_report_product_summary ps
LEFT JOIN goods g ON g.nm_id = ps.nm_id
LEFT JOIN goods_grp_active_multilang gg ON g.goods_grp_id = gg.id
LEFT JOIN goods_type_active_multilang gt ON gg.goods_type_id = gt.id
WHERE ps.quantity != 0 OR ps.volume != 0 OR ps.cost_price != 0;

COMMENT ON VIEW wb_fi_report_product_summary_view IS 
'Product summary view with sales_correction, quantity and volume before revenue';

COMMIT;

-- Rollback:
-- BEGIN;
-- DROP VIEW IF EXISTS wb_fi_report_summary_view CASCADE;
-- DROP VIEW IF EXISTS wb_fi_report_product_summary_view CASCADE;
-- CREATE VIEW wb_fi_report_summary_view AS ... (previous version without sales_correction);
-- CREATE VIEW wb_fi_report_product_summary_view AS ... (previous version without sales_correction);
-- COMMIT;