-- ============================================================================
-- Migration: fix_product_summary_quantity_volume_order
-- Description: Calculate quantity and volume AFTER other fields
-- ============================================================================

BEGIN;

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
    v_field RECORD;
    v_qv RECORD;
    v_total_quantity NUMERIC(15,3) := 0;
    v_total_volume NUMERIC(15,2) := 0;
BEGIN
    -- 1. Get combined report_ids
    v_report_ids := get_combined_report_ids(p_user_id, p_report_id);
    v_combined_report_id := v_report_ids[1];
    
    -- 2. Clear existing summary
    DELETE FROM wb_fi_report_summary 
    WHERE user_id = p_user_id AND report_id = v_combined_report_id;
    
    -- 3. Clear existing product summary
    DELETE FROM wb_fi_report_product_summary 
    WHERE user_id = p_user_id AND report_id = v_combined_report_id;
    
    -- 4. Calculate basic metrics
    v_metrics := calculate_wb_basic_metrics(p_user_id, v_report_ids);
    
    -- 5. Insert summary (without quantity and volume yet)
    PERFORM insert_wb_basic_metrics(p_user_id, v_combined_report_id, v_metrics);
    
    -- 6. Create product records
    INSERT INTO wb_fi_report_product_summary (user_id, report_id, nm_id)
    SELECT 
        p_user_id,
        v_combined_report_id,
        d.nm_id
    FROM wb_fi_report_details d
    WHERE d.user_id = p_user_id 
      AND d.report_id = ANY(v_report_ids)
      AND d.nm_id IS NOT NULL
      AND d.nm_id != 0
    GROUP BY d.nm_id
    ON CONFLICT (user_id, report_id, nm_id) DO NOTHING;
    
    -- 7. Calculate all fields using wb_sum_by_product_rule (EXCEPT quantity and volume)
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
            SELECT * FROM wb_sum_by_product_rule(p_user_id, v_report_ids, v_field.target_field, v_field.source_field, 'add')
        ) sub
        WHERE ps.user_id = p_user_id 
          AND ps.report_id = v_combined_report_id 
          AND ps.nm_id = sub.nm_id;
    END LOOP;
    
    -- 8. Calculate quantity and volume (AFTER all other fields)
    INSERT INTO wb_fi_report_product_summary (
        user_id, report_id, nm_id, quantity, volume
    )
    SELECT 
        p_user_id,
        v_combined_report_id,
        nm_id,
        quantity,
        volume
    FROM calculate_wb_product_quantity_volume_cost(p_user_id, v_report_ids)
    WHERE quantity != 0 OR volume != 0
    ON CONFLICT (user_id, report_id, nm_id) 
    DO UPDATE SET 
        quantity = EXCLUDED.quantity,
        volume = EXCLUDED.volume;
    
    -- 9. Update summary with total quantity and volume
    SELECT * INTO v_qv 
    FROM calculate_wb_total_quantity_volume_cost(p_user_id, v_report_ids);
    
    v_total_quantity := COALESCE(v_qv.total_quantity, 0);
    v_total_volume := COALESCE(v_qv.total_volume, 0);
    
    UPDATE wb_fi_report_summary
    SET 
        quantity = v_total_quantity,
        volume = v_total_volume
    WHERE user_id = p_user_id AND report_id = v_combined_report_id;
    
    -- 10. Update complex fields
    PERFORM update_wb_complex_fields(p_user_id, v_report_ids, v_combined_report_id);
    
    -- 11. Get processed count
    SELECT COUNT(*) INTO v_processed_count
    FROM wb_fi_report_details
    WHERE user_id = p_user_id 
      AND report_id = ANY(v_report_ids);
    
    -- 12. Find unmatched rows
    v_unmatched_count := find_wb_unmatched_rows(p_user_id, v_combined_report_id);
    
    -- 13. Get unmatched sample
    IF v_unmatched_count > 0 THEN
        SELECT get_wb_unmatched_sample(p_user_id, v_combined_report_id, 10) INTO v_unmatched_sample;
    END IF;
    
    -- 14. Return results
    RETURN QUERY SELECT 
        v_processed_count,
        TRUE,
        v_unmatched_count,
        COALESCE(v_unmatched_sample, '[]'::JSONB);
END;
$$;

COMMENT ON FUNCTION process_wb_report_details(INTEGER, BIGINT) IS 
'Process Wildberries financial report details with product-level aggregation.';

COMMIT;