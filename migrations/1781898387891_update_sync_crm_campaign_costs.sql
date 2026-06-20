-- ============================================================================
-- Migration: create_crm_campaign_costs_sync_function
-- Description: Function to sync campaign costs (upsert by upd_num + upd_time)
-- ============================================================================

BEGIN;

-- Create sync function
CREATE OR REPLACE FUNCTION sync_crm_campaign_costs(
    p_costs JSONB
)
RETURNS TABLE (
    processed INTEGER,
    inserted INTEGER,
    updated INTEGER,
    errors INTEGER
) LANGUAGE plpgsql AS $$
DECLARE
    v_cost RECORD;
    v_processed INTEGER := 0;
    v_inserted INTEGER := 0;
    v_updated INTEGER := 0;
    v_errors INTEGER := 0;
BEGIN
    -- Loop through each cost record in the JSON array
    FOR v_cost IN 
        SELECT * FROM jsonb_to_recordset(p_costs) AS x(
            upd_num INTEGER,
            upd_time TIMESTAMP,
            upd_sum NUMERIC(15,2),
            advert_id INTEGER,
            payment_type VARCHAR(100)
        )
    LOOP
        v_processed := v_processed + 1;
        
        BEGIN
            -- Upsert: insert or update on conflict
            INSERT INTO crm_campaign_costs (
                upd_num,
                upd_time,
                upd_sum,
                advert_id,
                payment_type
            ) VALUES (
                v_cost.upd_num,
                v_cost.upd_time,
                COALESCE(v_cost.upd_sum, 0),
                v_cost.advert_id,
                v_cost.payment_type
            )
            ON CONFLICT (upd_num, upd_time, advert_id) 
            DO UPDATE SET 
                upd_sum = EXCLUDED.upd_sum,
                advert_id = EXCLUDED.advert_id,
                payment_type = EXCLUDED.payment_type,
                updated_at = NOW();
            
            -- Check if it was insert or update
            IF EXISTS (
                SELECT 1 FROM crm_campaign_costs 
                WHERE upd_num = v_cost.upd_num 
                  AND upd_time = v_cost.upd_time
                  AND created_at = updated_at
            ) THEN
                v_inserted := v_inserted + 1;
            ELSE
                v_updated := v_updated + 1;
            END IF;
            
        EXCEPTION WHEN OTHERS THEN
            v_errors := v_errors + 1;
        END;
    END LOOP;
    
    RETURN QUERY SELECT v_processed, v_inserted, v_updated, v_errors;
END;
$$;

-- Add comment
COMMENT ON FUNCTION sync_crm_campaign_costs(JSONB) IS 'Sync campaign costs. Upsert by (upd_num, upd_time) composite key.';

COMMIT;

-- Rollback:
-- BEGIN;
-- DROP FUNCTION IF EXISTS sync_crm_campaign_costs(JSONB);
-- COMMIT;