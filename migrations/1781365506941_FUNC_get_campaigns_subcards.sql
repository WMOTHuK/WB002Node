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
                INSERT INTO crm_campaign_subcards (advertid, vendorcode)
                VALUES (p_advertid, v_item.vendorcode)
                ON CONFLICT (advertid, vendorcode) DO NOTHING;
                
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
                WHERE advertid = p_advertid 
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

COMMENT ON FUNCTION sync_campaign_subcards(INTEGER, JSONB) IS 'Sync campaign-subcard links. Items: [{"vendorcode": "ABC", "has_link": true}]';