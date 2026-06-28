-- ============================================================================
-- Migration: create_wb_fi_report_product_summary_view
-- Description: Unified view for product summary with all fields for pivot
-- ============================================================================

BEGIN;

-- 1. Удалить существующий VIEW
DROP VIEW IF EXISTS wb_fi_report_product_summary_view CASCADE;

-- 2. Создать VIEW заново
CREATE VIEW wb_fi_report_product_summary_view AS
SELECT 
    ps.report_id,
    gg.goods_type_id,
    COALESCE(gt.name_ru, 'Без типа') AS goods_type_name,
    g.goods_grp_id,
    COALESCE(gg.name_ru, 'Без группы') AS goods_grp_name,
    g.title,
    g.vendorcode,
    ps.revenue,
    ps.cost_price,
    ps.for_pay,
    ps.logistics_total,
    ps.advertising,
    ps.storage,
    ps.fines,
    ps.acceptance,
    ps.transit,
    ps.disposal,
    ps.quantity,
    ps.volume,
    ps.seller_tax,
    ps.overheads,
    ps.report_totals
FROM wb_fi_report_product_summary ps
LEFT JOIN goods g ON g.nm_id = ps.nm_id
LEFT JOIN goods_grp_active_multilang gg ON g.goods_grp_id = gg.id
LEFT JOIN goods_type_active_multilang gt ON gg.goods_type_id = gt.id
WHERE ps.quantity != 0 OR ps.volume != 0 OR ps.cost_price != 0;

COMMENT ON VIEW wb_fi_report_product_summary_view IS 
'Product summary view with all metric fields for pivot/transposition';

COMMIT;

-- Rollback:
-- BEGIN;
-- DROP VIEW IF EXISTS wb_fi_report_product_summary_view CASCADE;
-- COMMIT;