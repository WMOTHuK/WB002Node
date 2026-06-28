-- ============================================================================
-- Migration: recreate_wb_fi_report_product_summary_view
-- Description: Recreate view with all logistics fields in same order as summary view
-- ============================================================================

BEGIN;

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
    -- Поля в том же порядке, что и в wb_fi_report_summary_view
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
    ps.quantity,
    ps.volume
FROM wb_fi_report_product_summary ps
LEFT JOIN goods g ON g.nm_id = ps.nm_id
LEFT JOIN goods_grp_active_multilang gg ON g.goods_grp_id = gg.id
LEFT JOIN goods_type_active_multilang gt ON gg.goods_type_id = gt.id
WHERE ps.quantity != 0 OR ps.volume != 0 OR ps.cost_price != 0;

COMMENT ON VIEW wb_fi_report_product_summary_view IS 
'Product summary view with all fields in same order as wb_fi_report_summary_view';

COMMIT;