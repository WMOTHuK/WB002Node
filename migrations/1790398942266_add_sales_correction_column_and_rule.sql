-- ============================================================================
-- Migration: add_sales_correction_column_and_rule
-- Description: Add sales_correction column and processing rule
-- ============================================================================

BEGIN;

-- ============================================================================
-- 1. Добавить столбец sales_correction в wb_fi_report_summary
-- ============================================================================

ALTER TABLE wb_fi_report_summary 
ADD COLUMN IF NOT EXISTS sales_correction NUMERIC(15,2) DEFAULT 0;

COMMENT ON COLUMN wb_fi_report_summary.sales_correction IS 'Sales correction (Коррекция продаж)';

-- ============================================================================
-- 2. Добавить столбец sales_correction в wb_fi_report_product_summary
-- ============================================================================

ALTER TABLE wb_fi_report_product_summary 
ADD COLUMN IF NOT EXISTS sales_correction NUMERIC(15,2) DEFAULT 0;

COMMENT ON COLUMN wb_fi_report_product_summary.sales_correction IS 'Sales correction (Коррекция продаж)';

-- ============================================================================
-- 3. Добавить правило для sales_correction
-- ============================================================================

INSERT INTO wb_fi_processing_rules (
    rule_name,
    seller_oper_name,
    action,
    target_field,
    amount_source,
    priority
) VALUES (
    'Коррекция продаж',
    'Коррекция продаж',
    'add',
    'sales_correction',
    'for_pay',
    25
)
ON CONFLICT DO NOTHING;

-- ============================================================================
-- 4. Обновить update_product_fields (добавить sales_correction в цикл)
-- ============================================================================

DROP FUNCTION IF EXISTS update_product_fields(INTEGER, BIGINT, BIGINT[]);

CREATE OR REPLACE FUNCTION update_product_fields(
    p_user_id INTEGER,
    p_report_id BIGINT,
    p_report_ids BIGINT[]
)
RETURNS VOID LANGUAGE plpgsql AS $$
DECLARE
    v_field RECORD;
BEGIN
    FOR v_field IN 
        SELECT 
            'revenue' AS target_field, 'retail_amount' AS source_field
        UNION ALL SELECT 'for_pay', 'for_pay'
        UNION ALL SELECT 'payback_for_return', 'for_pay'
        UNION ALL SELECT 'logistics_total', 'delivery_service'
        UNION ALL SELECT 'logistics_to_client_sale', 'delivery_service'
        UNION ALL SELECT 'logistics_to_client_cancel', 'delivery_service'
        UNION ALL SELECT 'logistics_to_seller_callback', 'delivery_service'
        UNION ALL SELECT 'logistics_to_seller_defect', 'delivery_service'
        UNION ALL SELECT 'logistics_to_seller_unidentified', 'delivery_service'
        UNION ALL SELECT 'logistics_from_client_cancel', 'delivery_service'
        UNION ALL SELECT 'logistics_from_client_return', 'delivery_service'
        UNION ALL SELECT 'logistics_correction', 'delivery_service'
        UNION ALL SELECT 'advertising', 'deduction'
        UNION ALL SELECT 'storage', 'paid_storage'
        UNION ALL SELECT 'fines', 'penalty'
        UNION ALL SELECT 'acceptance', 'paid_acceptance'
        UNION ALL SELECT 'transit', 'deduction'
        UNION ALL SELECT 'disposal', 'deduction'
        UNION ALL SELECT 'loss_compensation', 'additional_payment'
        UNION ALL SELECT 'freewill_compensation', 'for_pay'
        UNION ALL SELECT 'cost_price', 'retail_price'
        UNION ALL SELECT 'sales_correction', 'for_pay'
    LOOP
        UPDATE wb_fi_report_product_summary ps
        SET 
            revenue = CASE WHEN v_field.target_field = 'revenue' THEN sub.amount ELSE ps.revenue END,
            for_pay = CASE WHEN v_field.target_field = 'for_pay' THEN sub.amount ELSE ps.for_pay END,
            payback_for_return = CASE WHEN v_field.target_field = 'payback_for_return' THEN sub.amount ELSE ps.payback_for_return END,
            logistics_total = CASE WHEN v_field.target_field = 'logistics_total' THEN sub.amount ELSE ps.logistics_total END,
            logistics_to_client_sale = CASE WHEN v_field.target_field = 'logistics_to_client_sale' THEN sub.amount ELSE ps.logistics_to_client_sale END,
            logistics_to_client_cancel = CASE WHEN v_field.target_field = 'logistics_to_client_cancel' THEN sub.amount ELSE ps.logistics_to_client_cancel END,
            logistics_to_seller_callback = CASE WHEN v_field.target_field = 'logistics_to_seller_callback' THEN sub.amount ELSE ps.logistics_to_seller_callback END,
            logistics_to_seller_defect = CASE WHEN v_field.target_field = 'logistics_to_seller_defect' THEN sub.amount ELSE ps.logistics_to_seller_defect END,
            logistics_to_seller_unidentified = CASE WHEN v_field.target_field = 'logistics_to_seller_unidentified' THEN sub.amount ELSE ps.logistics_to_seller_unidentified END,
            logistics_from_client_cancel = CASE WHEN v_field.target_field = 'logistics_from_client_cancel' THEN sub.amount ELSE ps.logistics_from_client_cancel END,
            logistics_from_client_return = CASE WHEN v_field.target_field = 'logistics_from_client_return' THEN sub.amount ELSE ps.logistics_from_client_return END,
            logistics_correction = CASE WHEN v_field.target_field = 'logistics_correction' THEN sub.amount ELSE ps.logistics_correction END,
            advertising = CASE WHEN v_field.target_field = 'advertising' THEN sub.amount ELSE ps.advertising END,
            storage = CASE WHEN v_field.target_field = 'storage' THEN sub.amount ELSE ps.storage END,
            fines = CASE WHEN v_field.target_field = 'fines' THEN sub.amount ELSE ps.fines END,
            acceptance = CASE WHEN v_field.target_field = 'acceptance' THEN sub.amount ELSE ps.acceptance END,
            transit = CASE WHEN v_field.target_field = 'transit' THEN sub.amount ELSE ps.transit END,
            disposal = CASE WHEN v_field.target_field = 'disposal' THEN sub.amount ELSE ps.disposal END,
            loss_compensation = CASE WHEN v_field.target_field = 'loss_compensation' THEN sub.amount ELSE ps.loss_compensation END,
            freewill_compensation = CASE WHEN v_field.target_field = 'freewill_compensation' THEN sub.amount ELSE ps.freewill_compensation END,
            cost_price = CASE WHEN v_field.target_field = 'cost_price' THEN sub.amount ELSE ps.cost_price END,
            sales_correction = CASE WHEN v_field.target_field = 'sales_correction' THEN sub.amount ELSE ps.sales_correction END
        FROM (
            SELECT * FROM wb_sum_by_product_rule(p_user_id, p_report_ids, v_field.target_field, v_field.source_field, 'add')
        ) sub
        WHERE ps.user_id = p_user_id 
          AND ps.report_id = p_report_id 
          AND ps.nm_id = sub.nm_id;
    END LOOP;
END;
$$;

-- ============================================================================
-- 5. Обновить update_report_totals (учесть sales_correction в формуле)
-- ============================================================================

DROP FUNCTION IF EXISTS update_report_totals(INTEGER, BIGINT);

CREATE OR REPLACE FUNCTION update_report_totals(
    p_user_id INTEGER,
    p_report_id BIGINT
)
RETURNS VOID LANGUAGE plpgsql AS $$
DECLARE
    v_report_totals NUMERIC(15,2);
BEGIN
    -- Update product summary report_totals
    UPDATE wb_fi_report_product_summary
    SET report_totals = 
        COALESCE(for_pay, 0) 
        + COALESCE(sales_correction, 0)
        - COALESCE(payback_for_return, 0)
        - COALESCE(logistics_total, 0)
        - COALESCE(logistics_correction, 0)
        - COALESCE(advertising, 0)
        - COALESCE(storage, 0)
        - COALESCE(fines, 0)
        - COALESCE(acceptance, 0)
        - COALESCE(transit, 0)
        - COALESCE(disposal, 0)
        + COALESCE(loss_compensation, 0)
        + COALESCE(freewill_compensation, 0)
        - COALESCE(seller_tax, 0)
        - COALESCE(overheads, 0)
        - COALESCE(cost_price, 0)
    WHERE user_id = p_user_id AND report_id = p_report_id;
    
    -- Update summary report_totals
    SELECT 
        COALESCE(for_pay, 0) 
        + COALESCE(sales_correction, 0)
        - COALESCE(payback_for_return, 0)
        - COALESCE(logistics_total, 0)
        - COALESCE(logistics_correction, 0)
        - COALESCE(advertising, 0)
        - COALESCE(storage, 0)
        - COALESCE(fines, 0)
        - COALESCE(acceptance, 0)
        - COALESCE(transit, 0)
        - COALESCE(disposal, 0)
        + COALESCE(loss_compensation, 0)
        + COALESCE(freewill_compensation, 0)
        - COALESCE(seller_tax, 0)
        - COALESCE(overheads, 0)
        - COALESCE(cost_price, 0) INTO v_report_totals
    FROM wb_fi_report_summary
    WHERE user_id = p_user_id AND report_id = p_report_id;
    
    UPDATE wb_fi_report_summary
    SET report_totals = v_report_totals
    WHERE user_id = p_user_id AND report_id = p_report_id;
END;
$$;

COMMIT;