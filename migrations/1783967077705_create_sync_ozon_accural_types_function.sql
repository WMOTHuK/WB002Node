-- ============================================================================
-- Migration: create_sync_ozon_accural_types_function
-- Description: Function to sync Ozon accrual types from server
-- ============================================================================

BEGIN;

DROP FUNCTION IF EXISTS sync_ozon_accural_types(JSONB);

CREATE OR REPLACE FUNCTION sync_ozon_accural_types(
    p_items JSONB
)
RETURNS TABLE (
    processed INTEGER,
    inserted INTEGER,
    updated INTEGER,
    errors INTEGER
) LANGUAGE plpgsql AS $$
DECLARE
    v_item RECORD;
    v_processed INTEGER := 0;
    v_inserted INTEGER := 0;
    v_updated INTEGER := 0;
    v_errors INTEGER := 0;
    v_operation TEXT;
BEGIN
    -- Loop through each item in the JSON array
    FOR v_item IN 
        SELECT * FROM jsonb_to_recordset(p_items) AS x(
            id INTEGER,
            name VARCHAR(255),
            description TEXT
        )
    LOOP
        v_processed := v_processed + 1;
        
        BEGIN
            -- Upsert: insert or update on conflict
            INSERT INTO ozon_accural_types (
                id,
                name,
                description
            ) VALUES (
                v_item.id,
                v_item.name,
                v_item.description
            )
            ON CONFLICT (id) 
            DO UPDATE SET 
                name = EXCLUDED.name,
                description = EXCLUDED.description,
                updated_at = NOW()
            RETURNING (CASE WHEN xmax = 0 THEN 'insert' ELSE 'update' END) INTO v_operation;
            
            IF v_operation = 'insert' THEN
                v_inserted := v_inserted + 1;
            ELSE
                v_updated := v_updated + 1;
            END IF;
            
        EXCEPTION WHEN OTHERS THEN
            v_errors := v_errors + 1;
            RAISE NOTICE 'Error processing id %: %', v_item.id, SQLERRM;
        END;
    END LOOP;
    
    RETURN QUERY SELECT v_processed, v_inserted, v_updated, v_errors;
END;
$$;

COMMENT ON FUNCTION sync_ozon_accural_types(JSONB) IS 
'Sync Ozon accrual types. Upsert by id.';

COMMIT;