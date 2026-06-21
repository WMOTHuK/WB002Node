-- ============================================================================
-- Migration: rename_nmid_to_nm_id
-- Description: Rename nmid to nm_id across all tables and views
-- ============================================================================

BEGIN;

-- 1. Переименовать в таблице goods
ALTER TABLE goods RENAME COLUMN nmid TO nm_id;

-- 2. Переименовать в таблице prices
ALTER TABLE prices RENAME COLUMN nmid TO nm_id;

-- 3. Пересоздать VIEW product_data (зависит от goods.nmid)
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
    cp.cost_value AS current_cost,
    CURRENT_DATE AS change_date,
    g.deleted,
    COALESCE(gt.name_ru, '') AS goods_type_name,
    g.goods_grp_id,
    COALESCE(gg.name_ru, '') AS goods_grp_name
FROM goods g
LEFT JOIN cost_price cp ON cp.vendorcode = g.vendorcode AND cp.end_date IS NULL
LEFT JOIN goods_grp_active_multilang gg ON g.goods_grp_id = gg.id
LEFT JOIN goods_type_active_multilang gt ON gg.goods_type_id = gt.id
ORDER BY g.vendorcode;

-- 4. Обновить комментарии
COMMENT ON COLUMN goods.nm_id IS 'Wildberries product ID';
COMMENT ON COLUMN prices.nm_id IS 'Wildberries product ID';

COMMIT;

-- Rollback:
-- BEGIN;
-- DROP VIEW IF EXISTS product_data CASCADE;
-- ALTER TABLE goods RENAME COLUMN nm_id TO nmid;
-- ALTER TABLE prices RENAME COLUMN nm_id TO nmid;
-- CREATE OR REPLACE VIEW product_data AS ... (previous version);
-- COMMIT;