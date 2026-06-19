-- ============================================================================
-- Migration: fix_upsert_user_tax_rate_id_ambiguous
-- Description: Fix ambiguous id column references
-- ============================================================================

BEGIN;

DROP FUNCTION IF EXISTS upsert_user_tax_rate(INTEGER, NUMERIC, NUMERIC, DATE);

CREATE OR REPLACE FUNCTION upsert_user_tax_rate(
    p_user_id INTEGER,
    p_seller_tax_rate NUMERIC DEFAULT NULL,
    p_vat_tax_rate NUMERIC DEFAULT NULL,
    p_valid_from DATE DEFAULT NULL
)
RETURNS TABLE (
    id INTEGER,
    user_id INTEGER,
    seller_tax_rate NUMERIC,
    vat_tax_rate NUMERIC,
    valid_from DATE,
    valid_to DATE,
    action TEXT
) LANGUAGE plpgsql AS $$
DECLARE
    v_current_record RECORD;
    v_new_id INTEGER;
    v_valid_from DATE;
    v_seller_tax_rate NUMERIC(5,2);
    v_vat_tax_rate NUMERIC(5,2);
    v_action TEXT;
BEGIN
    -- Use current date if valid_from not provided
    v_valid_from := COALESCE(p_valid_from, CURRENT_DATE);
    
    -- Get current rates if they exist
    SELECT t.seller_tax_rate, t.vat_tax_rate 
    INTO v_seller_tax_rate, v_vat_tax_rate
    FROM user_tax_rates t
    WHERE t.user_id = p_user_id
      AND t.valid_from <= v_valid_from
      AND t.valid_to >= v_valid_from
    ORDER BY t.valid_from DESC
    LIMIT 1;
    
    -- If no existing rates, use defaults or provided values
    IF v_seller_tax_rate IS NULL THEN
        v_seller_tax_rate := COALESCE(p_seller_tax_rate, 6.00);
        v_vat_tax_rate := COALESCE(p_vat_tax_rate, 0.00);
    ELSE
        v_seller_tax_rate := COALESCE(p_seller_tax_rate, v_seller_tax_rate);
        v_vat_tax_rate := COALESCE(p_vat_tax_rate, v_vat_tax_rate);
    END IF;
    
    -- Check if current active rate already matches
    SELECT t.id, t.user_id, t.seller_tax_rate, t.vat_tax_rate, t.valid_from, t.valid_to 
    INTO v_current_record
    FROM user_tax_rates t
    WHERE t.user_id = p_user_id
      AND t.valid_from <= v_valid_from
      AND t.valid_to >= v_valid_from
    ORDER BY t.valid_from DESC
    LIMIT 1;
    
    -- If current rate exists and matches, do nothing
    IF v_current_record.id IS NOT NULL AND 
       v_current_record.seller_tax_rate = v_seller_tax_rate AND 
       v_current_record.vat_tax_rate = v_vat_tax_rate THEN
        v_action := 'unchanged';
        RETURN QUERY SELECT 
            v_current_record.id,
            v_current_record.user_id,
            v_current_record.seller_tax_rate,
            v_current_record.vat_tax_rate,
            v_current_record.valid_from,
            v_current_record.valid_to,
            v_action;
        RETURN;
    END IF;
    
    -- If current rate exists but differs, close it
    IF v_current_record.id IS NOT NULL THEN
        UPDATE user_tax_rates t
        SET valid_to = v_valid_from - INTERVAL '1 day',
            updated_at = NOW()
        WHERE t.id = v_current_record.id;
    END IF;
    
    -- Insert new rate
    INSERT INTO user_tax_rates (user_id, seller_tax_rate, vat_tax_rate, valid_from, valid_to)
    VALUES (p_user_id, v_seller_tax_rate, v_vat_tax_rate, v_valid_from, '9999-12-31')
    RETURNING user_tax_rates.id INTO v_new_id;
    
    v_action := 'inserted';
    
    RETURN QUERY SELECT 
        v_new_id,
        p_user_id,
        v_seller_tax_rate,
        v_vat_tax_rate,
        v_valid_from,
        '9999-12-31'::DATE,
        v_action;
END;
$$;

COMMENT ON FUNCTION upsert_user_tax_rate(INTEGER, NUMERIC, NUMERIC, DATE) IS 
'Upsert tax rate with period management. Uses seller_tax_rate and vat_tax_rate.';

COMMIT;