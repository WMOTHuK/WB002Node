-- ============================================================================
-- Migration: create_goods_grp_with_types_view
-- Description: View that returns all goods groups with their associated types
-- ============================================================================

BEGIN;

-- Create view for goods groups with their types
CREATE OR REPLACE VIEW goods_grp_with_types AS
SELECT 
    gg.id AS goods_grp_id,
    gg.name_ru AS goods_grp_name,
    gg.goods_type_id,
    COALESCE(gt.name_ru, 'Без типа') AS goods_type_name
FROM goods_grp_active_multilang gg
LEFT JOIN goods_type_active_multilang gt ON gg.goods_type_id = gt.id
ORDER BY gg.id;

-- Add comment
COMMENT ON VIEW goods_grp_with_types IS 'All goods groups with their associated types (type name defaults to "Без типа" if not set)';

COMMIT;

-- Rollback:
-- BEGIN;
-- DROP VIEW IF EXISTS goods_grp_with_types;
-- COMMIT;