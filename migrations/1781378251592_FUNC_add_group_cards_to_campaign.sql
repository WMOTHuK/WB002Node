-- ============================================================================
-- Function: add_group_cards_to_campaign
-- Description: Add all cards from a goods group to campaign subcards
-- ============================================================================

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
      AND g.nmid IS NOT NULL
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

COMMENT ON FUNCTION add_group_cards_to_campaign(INTEGER, INTEGER) IS 'Add all cards from a goods group to campaign subcards';