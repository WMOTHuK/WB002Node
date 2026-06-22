-- ============================================================================
-- Migration: update_complex_rules_for_products
-- Description: Update complex rules to populate product summary
-- ============================================================================

BEGIN;

-- 1. Обновить calculate_wb_seller_tax (для продуктов)
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
    -- Get date_from from first report
    SELECT date_from, report_id INTO v_date_from, v_report_id
    FROM wb_fi_report_headers
    WHERE user_id = p_user_id AND report_id = ANY(p_report_ids)
    LIMIT 1;
    
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

-- 2. Обновить update_wb_complex_fields
DROP FUNCTION IF EXISTS update_wb_complex_fields(INTEGER, BIGINT[], BIGINT);

CREATE OR REPLACE FUNCTION update_wb_complex_fields(
    p_user_id INTEGER,
    p_report_ids BIGINT[],
    p_summary_report_id BIGINT
)
RETURNS VOID LANGUAGE plpgsql AS $$
DECLARE
    v_product RECORD;
    v_seller_tax_total NUMERIC(15,2) := 0;
BEGIN
    -- Update seller_tax in product summary
    FOR v_product IN 
        SELECT * FROM calculate_wb_seller_tax_by_product(p_user_id, p_report_ids)
    LOOP
        UPDATE wb_fi_report_product_summary
        SET seller_tax = v_product.seller_tax
        WHERE user_id = p_user_id 
          AND report_id = p_summary_report_id 
          AND nm_id = v_product.nm_id;
        
        v_seller_tax_total := v_seller_tax_total + v_product.seller_tax;
    END LOOP;
    
    -- Update summary table
    UPDATE wb_fi_report_summary
    SET 
        seller_tax = v_seller_tax_total,
        overheads = calculate_wb_overheads(p_user_id, p_report_ids),
        report_totals = calculate_wb_report_totals(p_user_id, p_report_ids),
        logistics_total = calculate_wb_logistics_total(p_user_id, p_report_ids)
    WHERE user_id = p_user_id AND report_id = p_summary_report_id;
END;
$$;

COMMENT ON FUNCTION update_wb_complex_fields(INTEGER, BIGINT[], BIGINT) IS 
'Updates complex fields including seller_tax by product and totals';

COMMIT;

-- Rollback:
-- BEGIN;
-- DROP FUNCTION IF EXISTS calculate_wb_seller_tax_by_product(INTEGER, BIGINT[]);
-- DROP FUNCTION IF EXISTS update_wb_complex_fields(INTEGER, BIGINT[], BIGINT);
-- CREATE OR REPLACE FUNCTION update_wb_complex_fields(...) ... (previous version);
-- COMMIT;