-- ============================================================================
-- Migration: create_upsert_user_tax_rate_function
-- Description: Function to insert or update tax rate with period management
-- ============================================================================

BEGIN;

CREATE OR REPLACE FUNCTION upsert_user_tax_rate(
    p_user_id INTEGER,
    p_seller_tax NUMERIC(5,2) DEFAULT NULL,
    p_vat_tax NUMERIC(5,2) DEFAULT NULL,
    p_valid_from DATE DEFAULT NULL
)
RETURNS TABLE (
    id INTEGER,
    user_id INTEGER,
    seller_tax NUMERIC(5,2),
    vat_tax NUMERIC(5,2),
    valid_from DATE,
    valid_to DATE,
    action TEXT
) LANGUAGE plpgsql AS $$
DECLARE
    v_current_record RECORD;
    v_new_id INTEGER;
    v_valid_from DATE;
    v_seller_tax NUMERIC(5,2);
    v_vat_tax NUMERIC(5,2);
    v_action TEXT;
BEGIN
    -- Use current date if valid_from not provided
    v_valid_from := COALESCE(p_valid_from, CURRENT_DATE);
    
    -- Use existing values if not provided, else use provided
    SELECT seller_tax, vat_tax INTO v_seller_tax, v_vat_tax
    FROM user_tax_rates
    WHERE user_id = p_user_id
      AND valid_from <= v_valid_from
      AND valid_to >= v_valid_from
    ORDER BY valid_from DESC
    LIMIT 1;
    
    IF v_seller_tax IS NULL THEN
        v_seller_tax := COALESCE(p_seller_tax, 6.00);
        v_vat_tax := COALESCE(p_vat_tax, 0.00);
    ELSE
        v_seller_tax := COALESCE(p_seller_tax, v_seller_tax);
        v_vat_tax := COALESCE(p_vat_tax, v_vat_tax);
    END IF;
    
    -- Check if current active rate already matches
    SELECT * INTO v_current_record
    FROM user_tax_rates
    WHERE user_id = p_user_id
      AND valid_from <= v_valid_from
      AND valid_to >= v_valid_from
    ORDER BY valid_from DESC
    LIMIT 1;
    
    -- If current rate exists and matches, do nothing
    IF v_current_record.id IS NOT NULL AND 
       v_current_record.seller_tax = v_seller_tax AND 
       v_current_record.vat_tax = v_vat_tax THEN
        v_action := 'unchanged';
        RETURN QUERY SELECT 
            v_current_record.id,
            v_current_record.user_id,
            v_current_record.seller_tax,
            v_current_record.vat_tax,
            v_current_record.valid_from,
            v_current_record.valid_to,
            v_action;
        RETURN;
    END IF;
    
    -- If current rate exists but differs, close it
    IF v_current_record.id IS NOT NULL THEN
        UPDATE user_tax_rates
        SET valid_to = v_valid_from - INTERVAL '1 day',
            updated_at = NOW()
        WHERE id = v_current_record.id;
    END IF;
    
    -- Insert new rate
    INSERT INTO user_tax_rates (user_id, seller_tax, vat_tax, valid_from, valid_to)
    VALUES (p_user_id, v_seller_tax, v_vat_tax, v_valid_from, '9999-12-31')
    RETURNING id INTO v_new_id;
    
    v_action := 'inserted';
    
    RETURN QUERY SELECT 
        v_new_id,
        p_user_id,
        v_seller_tax,
        v_vat_tax,
        v_valid_from,
        '9999-12-31'::DATE,
        v_action;
END;
$$;

COMMENT ON FUNCTION upsert_user_tax_rate(INTEGER, NUMERIC, NUMERIC, DATE) IS 
'Upsert tax rate with period management. If rate changed, closes old period and creates new one.';

COMMIT;