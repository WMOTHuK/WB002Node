-- ============================================================================
-- Migration: refactor_process_wb_report_details
-- Description: Refactor process_wb_report_details into smaller functions
-- ============================================================================

BEGIN;

-- ============================================================================
-- 1. Вспомогательная функция для очистки данных отчёта
-- ============================================================================
CREATE OR REPLACE FUNCTION clear_report_data(
    p_user_id INTEGER,
    p_report_id BIGINT
)
RETURNS VOID LANGUAGE plpgsql AS $$
BEGIN
    DELETE FROM wb_fi_report_summary 
    WHERE user_id = p_user_id AND report_id = p_report_id;
    
    DELETE FROM wb_fi_report_product_summary 
    WHERE user_id = p_user_id AND report_id = p_report_id;
END;
$$;

-- ============================================================================
-- 2. Вспомогательная функция для создания записей продуктов
-- ============================================================================
CREATE OR REPLACE FUNCTION create_product_records(
    p_user_id INTEGER,
    p_report_id BIGINT,
    p_report_ids BIGINT[]
)
RETURNS VOID LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO wb_fi_report_product_summary (user_id, report_id, nm_id)
    SELECT 
        p_user_id,
        p_report_id,
        d.nm_id
    FROM wb_fi_report_details d
    WHERE d.user_id = p_user_id 
      AND d.report_id = ANY(p_report_ids)
      AND d.nm_id IS NOT NULL
      AND d.nm_id != 0
    GROUP BY d.nm_id
    ON CONFLICT (user_id, report_id, nm_id) DO NOTHING;
END;
$$;

-- ============================================================================
-- 3. Вспомогательная функция для обновления полей продуктов
-- ============================================================================
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
            cost_price = CASE WHEN v_field.target_field = 'cost_price' THEN sub.amount ELSE ps.cost_price END
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
-- 4. Вспомогательная функция для обновления quantity, volume, cost_price
-- ============================================================================
CREATE OR REPLACE FUNCTION update_product_quantity_volume_cost(
    p_user_id INTEGER,
    p_report_id BIGINT,
    p_report_ids BIGINT[]
)
RETURNS VOID LANGUAGE plpgsql AS $$
BEGIN
    INSERT INTO wb_fi_report_product_summary (
        user_id, report_id, nm_id, quantity, volume, cost_price
    )
    SELECT 
        p_user_id,
        p_report_id,
        nm_id,
        quantity,
        volume,
        cost_price
    FROM calculate_wb_product_quantity_volume_cost(p_user_id, p_report_ids)
    WHERE quantity != 0 OR volume != 0 OR cost_price != 0
    ON CONFLICT (user_id, report_id, nm_id) 
    DO UPDATE SET 
        quantity = EXCLUDED.quantity,
        volume = EXCLUDED.volume,
        cost_price = EXCLUDED.cost_price;
END;
$$;

-- ============================================================================
-- 5. Вспомогательная функция для обновления summary с quantity/volume/cost_price
-- ============================================================================
CREATE OR REPLACE FUNCTION update_summary_quantity_volume_cost(
    p_user_id INTEGER,
    p_report_id BIGINT,
    p_report_ids BIGINT[]
)
RETURNS VOID LANGUAGE plpgsql AS $$
DECLARE
    v_qv RECORD;
BEGIN
    SELECT * INTO v_qv 
    FROM calculate_wb_total_quantity_volume_cost(p_user_id, p_report_ids);
    
    UPDATE wb_fi_report_summary
    SET 
        quantity = COALESCE(v_qv.total_quantity, 0),
        volume = COALESCE(v_qv.total_volume, 0),
        cost_price = COALESCE(v_qv.total_cost_price, 0)
    WHERE user_id = p_user_id AND report_id = p_report_id;
END;
$$;

-- ============================================================================
-- 6. Вспомогательная функция для обновления report_totals
-- ============================================================================
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
        - COALESCE(payback_for_return, 0)
        - COALESCE(logistics_total, 0)
        + COALESCE(logistics_correction, 0)
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
        - COALESCE(payback_for_return, 0)
        - COALESCE(logistics_total, 0)
        + COALESCE(logistics_correction, 0)
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

-- ============================================================================
-- 7. Рефакторинг основной функции process_wb_report_details
-- ============================================================================
DROP FUNCTION IF EXISTS process_wb_report_details(INTEGER, BIGINT);

CREATE OR REPLACE FUNCTION process_wb_report_details(
    p_user_id INTEGER,
    p_report_id BIGINT
)
RETURNS TABLE (
    processed_count INTEGER,
    summary_updated BOOLEAN,
    unmatched_count INTEGER,
    unmatched_sample JSONB
) LANGUAGE plpgsql AS $$
DECLARE
    v_report_ids BIGINT[];
    v_combined_report_id BIGINT;
    v_processed_count INTEGER := 0;
    v_unmatched_count INTEGER := 0;
    v_unmatched_sample JSONB := '[]'::JSONB;
    v_metrics JSONB;
BEGIN
    -- 1. Get combined report_ids (type 1 + type 2 paired)
    v_report_ids := get_combined_report_ids(p_user_id, p_report_id);
    v_combined_report_id := v_report_ids[1];
    
    -- 2. Clear existing data
    PERFORM clear_report_data(p_user_id, v_combined_report_id);
    
    -- 3. Calculate basic metrics and insert summary
    v_metrics := calculate_wb_basic_metrics(p_user_id, v_report_ids);
    PERFORM insert_wb_basic_metrics(p_user_id, v_combined_report_id, v_metrics);
    
    -- 4. Create product records
    PERFORM create_product_records(p_user_id, v_combined_report_id, v_report_ids);
    
    -- 5. Update product fields (revenue, for_pay, logistics, etc.)
    PERFORM update_product_fields(p_user_id, v_combined_report_id, v_report_ids);
    
    -- 6. Update quantity, volume, cost_price for products
    PERFORM update_product_quantity_volume_cost(p_user_id, v_combined_report_id, v_report_ids);
    
    -- 7. Update summary with quantity, volume, cost_price
    PERFORM update_summary_quantity_volume_cost(p_user_id, v_combined_report_id, v_report_ids);
    
    -- 8. Update complex fields (seller_tax, overheads, logistics_total)
    PERFORM update_wb_complex_fields(p_user_id, v_report_ids, v_combined_report_id);
    
    -- 9. Update report_totals (LAST STEP)
    PERFORM update_report_totals(p_user_id, v_combined_report_id);
    
    -- 10. Get processed count
    SELECT COUNT(*) INTO v_processed_count
    FROM wb_fi_report_details
    WHERE user_id = p_user_id 
      AND report_id = ANY(v_report_ids);
    
    -- 11. Find unmatched rows
    v_unmatched_count := find_wb_unmatched_rows(p_user_id, v_combined_report_id);
    
    -- 12. Get unmatched sample
    IF v_unmatched_count > 0 THEN
        SELECT get_wb_unmatched_sample(p_user_id, v_combined_report_id, 10) INTO v_unmatched_sample;
    END IF;
    
    -- 13. Return results
    RETURN QUERY SELECT 
        v_processed_count,
        TRUE,
        v_unmatched_count,
        COALESCE(v_unmatched_sample, '[]'::JSONB);
END;
$$;

COMMENT ON FUNCTION process_wb_report_details(INTEGER, BIGINT) IS 
'Process Wildberries financial report details - refactored version with modular functions.';

COMMIT;