-- ============================================================================
-- Migration: update_process_wb_report_details_with_quantity_volume
-- Description: Integrate quantity and volume calculation into main process
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
    v_qv RECORD;  -- quantity_volume record
    v_product RECORD;
    v_total_quantity NUMERIC(15,3) := 0;
    v_total_volume NUMERIC(15,2) := 0;
BEGIN
    -- 1. Get combined report_ids (type 1 + type 2 paired)
    v_report_ids := get_combined_report_ids(p_user_id, p_report_id);
    v_combined_report_id := v_report_ids[1];  -- First is type 1 (main)
    
    -- 2. Clear existing summary for combined report
    DELETE FROM wb_fi_report_summary 
    WHERE user_id = p_user_id AND report_id = v_combined_report_id;
    
    -- 3. Clear existing product summary for combined report
    DELETE FROM wb_fi_report_product_summary 
    WHERE user_id = p_user_id AND report_id = v_combined_report_id;
    
    -- 4. Calculate basic metrics (revenue, for_pay, etc.)
    v_metrics := calculate_wb_basic_metrics(p_user_id, v_report_ids);
    
    -- 5. Insert summary (without quantity and volume yet)
    PERFORM insert_wb_basic_metrics(p_user_id, v_combined_report_id, v_metrics);
    
    -- 6. Calculate quantity and volume
    SELECT * INTO v_qv 
    FROM calculate_wb_total_quantity_volume(p_user_id, v_report_ids);
    
    v_total_quantity := COALESCE(v_qv.total_quantity, 0);
    v_total_volume := COALESCE(v_qv.total_volume, 0);
    
    -- 7. Update summary with quantity and volume
    UPDATE wb_fi_report_summary
    SET 
        quantity = v_total_quantity,
        volume = v_total_volume
    WHERE user_id = p_user_id AND report_id = v_combined_report_id;
    
    -- 8. Insert product-level quantity and volume
    INSERT INTO wb_fi_report_product_summary (
        user_id, report_id, nm_id, quantity, volume
    )
    SELECT 
        p_user_id,
        v_combined_report_id,
        nm_id,
        quantity,
        volume
    FROM calculate_wb_product_quantity_volume(p_user_id, v_report_ids)
    WHERE quantity != 0 OR volume != 0;
    
    -- 9. Update complex fields (overheads, seller_tax, report_totals, logistics_total)
    PERFORM update_wb_complex_fields(p_user_id, v_report_ids, v_combined_report_id);
    
    -- 10. Get processed count from combined reports
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
'Process Wildberries financial report details with quantity and volume support.';

COMMIT;

-- Rollback:
-- BEGIN;
-- DROP FUNCTION IF EXISTS process_wb_report_details(INTEGER, BIGINT);
-- CREATE OR REPLACE FUNCTION process_wb_report_details(...) ... (previous version without quantity/volume);
-- COMMIT;