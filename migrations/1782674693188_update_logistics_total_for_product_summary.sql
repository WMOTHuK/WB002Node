-- ============================================================================
-- Migration: update_logistics_total_for_product_summary
-- Description: Calculate logistics_total for product summary using the same logic
-- ============================================================================

BEGIN;

-- 1. Функция для расчёта logistics_total по товарам
CREATE OR REPLACE FUNCTION calculate_product_logistics_total(
    p_user_id INTEGER,
    p_report_ids BIGINT[]
)
RETURNS TABLE (
    nm_id BIGINT,
    logistics_total NUMERIC(15,2)
) LANGUAGE sql STABLE AS $$
    SELECT 
        d.nm_id,
        COALESCE(SUM(d.delivery_service::NUMERIC), 0) AS logistics_total
    FROM wb_fi_report_details d
    WHERE d.user_id = p_user_id 
      AND d.report_id = ANY(p_report_ids)
      AND d.nm_id IS NOT NULL
      AND d.nm_id != 0
      AND (d.delivery_amount::NUMERIC > 0 OR d.return_amount::NUMERIC > 0)
    GROUP BY d.nm_id
    ORDER BY d.nm_id;
$$;

-- 2. Обновить функцию update_wb_complex_fields
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
    v_logistics_total NUMERIC(15,2) := 0;
BEGIN
    -- 1. Update seller_tax in product summary
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
    
    -- 2. Update logistics_total in product summary
    FOR v_product IN 
        SELECT * FROM calculate_product_logistics_total(p_user_id, p_report_ids)
    LOOP
        UPDATE wb_fi_report_product_summary
        SET logistics_total = v_product.logistics_total
        WHERE user_id = p_user_id 
          AND report_id = p_summary_report_id 
          AND nm_id = v_product.nm_id;
    END LOOP;
    
    -- 3. Update summary table (seller_tax, overheads, logistics_total)
    SELECT calculate_wb_logistics_total(p_user_id, p_report_ids) INTO v_logistics_total;
    
    UPDATE wb_fi_report_summary
    SET 
        seller_tax = v_seller_tax_total,
        overheads = calculate_wb_overheads(p_user_id, p_report_ids),
        logistics_total = v_logistics_total
    WHERE user_id = p_user_id AND report_id = p_summary_report_id;
END;
$$;

COMMENT ON FUNCTION update_wb_complex_fields(INTEGER, BIGINT[], BIGINT) IS 
'Update complex fields including logistics_total for both summary and product summary';

COMMIT;

-- Rollback:
-- BEGIN;
-- DROP FUNCTION IF EXISTS calculate_product_logistics_total(INTEGER, BIGINT[]);
-- DROP FUNCTION IF EXISTS update_wb_complex_fields(INTEGER, BIGINT[], BIGINT);
-- CREATE OR REPLACE FUNCTION update_wb_complex_fields(...) ... (previous version);
-- COMMIT;