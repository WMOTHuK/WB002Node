-- ============================================================================
-- Migration: create_calculate_wb_seller_tax_function
-- Description: Calculate seller_tax as revenue * seller_tax_rate / 100
-- ============================================================================

BEGIN;

CREATE OR REPLACE FUNCTION calculate_wb_seller_tax(
    p_user_id INTEGER,
    p_report_id BIGINT
)
RETURNS NUMERIC(15,2) LANGUAGE plpgsql STABLE AS $$
DECLARE
    v_revenue NUMERIC(15,2);
    v_tax_rate NUMERIC(5,2);
    v_date_from DATE;
    v_result NUMERIC(15,2);
BEGIN
    -- Get date_from from report header
    SELECT date_from INTO v_date_from
    FROM wb_fi_report_headers
    WHERE user_id = p_user_id AND report_id = p_report_id;
    
    -- Get revenue from summary
    SELECT revenue INTO v_revenue
    FROM wb_fi_report_summary
    WHERE user_id = p_user_id AND report_id = p_report_id;
    
    -- Get seller_tax_rate for this user at the report date
    SELECT seller_tax_rate INTO v_tax_rate
    FROM user_tax_rates
    WHERE user_id = p_user_id
      AND valid_from <= v_date_from
      AND valid_to >= v_date_from
    ORDER BY valid_from DESC
    LIMIT 1;
    
    -- If no tax rate found, use default 6%
    IF v_tax_rate IS NULL THEN
        v_tax_rate := 6.00;
    END IF;
    
    -- Calculate: revenue * tax_rate / 100
    v_result := ROUND((COALESCE(v_revenue, 0) * v_tax_rate / 100), 2);
    
    RETURN v_result;
END;
$$;

COMMENT ON FUNCTION calculate_wb_seller_tax(INTEGER, BIGINT) IS 
'Calculates seller_tax as revenue * seller_tax_rate / 100. Uses tax rate valid at report date_from.';

COMMIT;