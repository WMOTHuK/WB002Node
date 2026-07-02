-- ============================================================================
-- Migration: fix_get_campaign_assignable_cards_advert_id
-- Description: Fix column name after renaming advertid to advert_id
-- ============================================================================

BEGIN;

DROP FUNCTION IF EXISTS get_campaign_assignable_cards(INTEGER);

CREATE OR REPLACE FUNCTION get_campaign_assignable_cards(p_advertid INTEGER)
RETURNS TABLE (
    card_photo TEXT,
    nm_id INTEGER,
    vendorcode VARCHAR(10),
    title VARCHAR(100),
    goods_type_id INTEGER,
    goods_type_name VARCHAR(255),
    goods_grp_id INTEGER,
    goods_grp_name VARCHAR(255),
    has_link BOOLEAN
) LANGUAGE sql STABLE AS $$
    SELECT 
        g.card_photo,
        g.nm_id,
        g.vendorcode,
        g.title,
        gg.goods_type_id,
        COALESCE(gt.name_ru, 'Без типа') AS goods_type_name,
        g.goods_grp_id,
        COALESCE(gg.name_ru, 'Без группы') AS goods_grp_name,
        CASE WHEN cs.vendorcode IS NOT NULL THEN TRUE ELSE FALSE END AS has_link
    FROM goods g
    LEFT JOIN goods_grp_active_multilang gg ON g.goods_grp_id = gg.id
    LEFT JOIN goods_type_active_multilang gt ON gg.goods_type_id = gt.id
    LEFT JOIN crm_campaign_subcards cs ON cs.vendorcode = g.vendorcode AND cs.advert_id = p_advertid
    WHERE g.nm_id IS NOT NULL 
      AND (g.deleted = FALSE OR g.deleted IS NULL)
    ORDER BY g.vendorcode;
$$;

COMMENT ON FUNCTION get_campaign_assignable_cards(INTEGER) IS 
'Returns assignable cards with has_link=true for cards linked to specified campaign.';

COMMIT;