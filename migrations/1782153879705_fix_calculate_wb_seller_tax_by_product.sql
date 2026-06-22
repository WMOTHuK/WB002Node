-- ============================================================================
-- Migration: fix_calculate_wb_seller_tax_by_product
-- Description: Use only report_type = 1 for date_from
-- ============================================================================

BEGIN;

DROP FUNCTION IF EXISTS calculate_wb_seller_tax_by_product(INTEGER, BIGINT[]);

CREATE OR REPLACE FUNCTION calculate_wb_seller_tax_by_product(
    p_user_id INTEGER,
    p_report_ids BIGINT[]
)
RETURNS TABLE (
    nm_id BIGINT,
    seller_tax NUMERIC(15,2)
) LANGUAGE plpgsql STABLE AS $$
DECLARE
    v_tax_rate NUMERIC(5,2);
    v_date_from DATE;
    v_report_id BIGINT;
BEGIN
    -- Get date_from from report_type = 1 ONLY
    SELECT h.date_from, h.report_id INTO v_date_from, v_report_id
    FROM wb_fi_report_headers h
    WHERE h.user_id = p_user_id 
      AND h.report_id = ANY(p_report_ids)
      AND h.report_type = 1  -- <-- Только тип 1
    LIMIT 1;
    
    -- If no type 1 found, try any report
    IF v_date_from IS NULL THEN
        SELECT h.date_from, h.report_id INTO v_date_from, v_report_id
        FROM wb_fi_report_headers h
        WHERE h.user_id = p_user_id 
          AND h.report_id = ANY(p_report_ids)
        LIMIT 1;
    END IF;
    
    -- If still no date, return empty
    IF v_date_from IS NULL THEN
        RETURN;
    END IF;
    
    -- Get tax rate for this user at report date
    SELECT seller_tax_rate INTO v_tax_rate
    FROM user_tax_rates
    WHERE user_id = p_user_id
      AND valid_from <= v_date_from
      AND valid_to >= v_date_from
    ORDER BY valid_from DESC
    LIMIT 1;
    
    IF v_tax_rate IS NULL THEN
        v_tax_rate := 6.00;
    END IF;
    
    RETURN QUERY
    SELECT 
        ps.nm_id,
        ROUND((ps.revenue * v_tax_rate / 100), 2) AS seller_tax
    FROM wb_fi_report_product_summary ps
    WHERE ps.user_id = p_user_id 
      AND ps.report_id = v_report_id
      AND ps.revenue != 0;
END;
$$;

COMMENT ON FUNCTION calculate_wb_seller_tax_by_product(INTEGER, BIGINT[]) IS 
'Calculate seller tax by product using report_type = 1 for date_from.';

COMMIT;