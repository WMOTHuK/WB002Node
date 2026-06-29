-- ============================================================================
-- Migration: update_product_data_with_separate_costs
-- Description: Add separate wb_current_cost and ozon_current_cost to product_data view
-- ============================================================================

BEGIN;

DROP VIEW IF EXISTS product_data CASCADE;

CREATE VIEW product_data AS
SELECT 
    g.card_photo,
    g.title,
    g.vendorcode,
    g.nm_id,
    g.wbvol,
    g.ozid,
    g.ozvol,
    g.imtid,
    cp.wb_cost_value AS wb_current_cost,
    cp.ozon_cost_value AS ozon_current_cost,
    '2026-01-01'::DATE AS change_date,
    g.deleted,
    COALESCE(gt.name_ru, '') AS goods_type_name,
    g.goods_grp_id,
    COALESCE(gg.name_ru, '') AS goods_grp_name
FROM goods g
LEFT JOIN cost_price cp ON cp.vendorcode = g.vendorcode AND cp.end_date IS NULL
LEFT JOIN goods_grp_active_multilang gg ON g.goods_grp_id = gg.id
LEFT JOIN goods_type_active_multilang gt ON gg.goods_type_id = gt.id
ORDER BY g.vendorcode;

COMMENT ON VIEW product_data IS 'Products with separate WB and Ozon current cost prices';

COMMIT;

-- Rollback:
-- BEGIN;
-- DROP VIEW IF EXISTS product_data CASCADE;
-- CREATE VIEW product_data AS ... (previous version);
-- COMMIT;