-- ============================================================================
-- Migration: fix_sync_campaign_subcards_and_add_group_advert_id
-- Description: Fix column name after renaming advertid to advert_id
-- ============================================================================

BEGIN;

-- 1. Обновить sync_campaign_subcards
DROP FUNCTION IF EXISTS sync_campaign_subcards(INTEGER, JSONB);

CREATE OR REPLACE FUNCTION sync_campaign_subcards(
    p_advertid INTEGER,
    p_items JSONB
)
RETURNS TABLE (
    processed INTEGER,
    inserted INTEGER,
    deleted INTEGER,
    errors INTEGER
) LANGUAGE plpgsql AS $$
DECLARE
    v_item RECORD;
    v_processed INTEGER := 0;
    v_inserted INTEGER := 0;
    v_deleted INTEGER := 0;
    v_errors INTEGER := 0;
BEGIN
    -- Loop through each item in the JSON array
    FOR v_item IN 
        SELECT * FROM jsonb_to_recordset(p_items) AS x(
            vendorcode VARCHAR(10),
            has_link BOOLEAN
        )
    LOOP
        v_processed := v_processed + 1;
        
        -- If has_link is true, insert (skip if already exists)
        IF v_item.has_link = TRUE THEN
            BEGIN
                INSERT INTO crm_campaign_subcards (advert_id, vendorcode)
                VALUES (p_advertid, v_item.vendorcode)
                ON CONFLICT (advert_id, vendorcode) DO NOTHING;
                
                IF FOUND THEN
                    v_inserted := v_inserted + 1;
                END IF;
            EXCEPTION WHEN OTHERS THEN
                v_errors := v_errors + 1;
            END;
            
        -- If has_link is false, delete (only if exists)
        ELSE
            BEGIN
                DELETE FROM crm_campaign_subcards
                WHERE advert_id = p_advertid 
                  AND vendorcode = v_item.vendorcode;
                
                IF FOUND THEN
                    v_deleted := v_deleted + 1;
                END IF;
            EXCEPTION WHEN OTHERS THEN
                v_errors := v_errors + 1;
            END;
        END IF;
    END LOOP;
    
    RETURN QUERY SELECT v_processed, v_inserted, v_deleted, v_errors;
END;
$$;

COMMENT ON FUNCTION sync_campaign_subcards(INTEGER, JSONB) IS 
'Sync campaign-subcard links. Items: [{"vendorcode": "ABC", "has_link": true}].';

-- 2. Обновить add_group_cards_to_campaign
DROP FUNCTION IF EXISTS add_group_cards_to_campaign(INTEGER, INTEGER);

CREATE OR REPLACE FUNCTION add_group_cards_to_campaign(
    p_advertid INTEGER,
    p_goods_grp_id INTEGER
)
RETURNS TABLE (
    processed INTEGER,
    inserted INTEGER,
    already_exists INTEGER,
    errors INTEGER
) LANGUAGE plpgsql AS $$
DECLARE
    v_items JSONB;
    v_result RECORD;
BEGIN
    -- Build JSON array of vendorcodes from the group
    SELECT jsonb_agg(
        jsonb_build_object(
            'vendorcode', g.vendorcode,
            'has_link', TRUE
        )
    ) INTO v_items
    FROM goods g
    WHERE g.goods_grp_id = p_goods_grp_id
      AND g.nm_id IS NOT NULL
      AND (g.deleted = FALSE OR g.deleted IS NULL);
    
    -- If no items found, return zeros
    IF v_items IS NULL THEN
        RETURN QUERY SELECT 0::INTEGER, 0::INTEGER, 0::INTEGER, 0::INTEGER;
        RETURN;
    END IF;
    
    -- Reuse sync_campaign_subcards function
    FOR v_result IN 
        SELECT * FROM sync_campaign_subcards(p_advertid, v_items)
    LOOP
        processed := v_result.processed;
        inserted := v_result.inserted;
        already_exists := v_result.processed - v_result.inserted - v_result.errors;
        errors := v_result.errors;
        RETURN NEXT;
    END LOOP;
END;
$$;

COMMENT ON FUNCTION add_group_cards_to_campaign(INTEGER, INTEGER) IS 
'Add all cards from a goods group to campaign subcards.';

COMMIT;