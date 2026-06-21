-- ============================================================================
-- Migration: fix_process_wb_report_details_use_find_function
-- Description: Use find_wb_unmatched_rows function instead of inline logic
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
BEGIN
    -- 1. Get combined report_ids (type 1 + type 2 paired)
    v_report_ids := get_combined_report_ids(p_user_id, p_report_id);
    v_combined_report_id := v_report_ids[1];  -- First is type 1 (main)
    
    -- 2. Clear existing summary for combined report
    DELETE FROM wb_fi_report_summary 
    WHERE user_id = p_user_id AND report_id = v_combined_report_id;
    
    -- 3. Calculate metrics from combined reports
    v_metrics := calculate_wb_basic_metrics(p_user_id, v_report_ids);
    
    -- 4. Insert summary (using the combined report_id)
    PERFORM insert_wb_basic_metrics(p_user_id, v_combined_report_id, v_metrics);
    
    -- 5. Update complex fields (using combined report_ids)
    PERFORM update_wb_complex_fields(p_user_id, v_report_ids, v_combined_report_id);
    
    -- 6. Get processed count from combined reports
    SELECT COUNT(*) INTO v_processed_count
    FROM wb_fi_report_details
    WHERE user_id = p_user_id 
      AND report_id = ANY(v_report_ids);
    
    -- 7. Find unmatched rows (using the function with LIKE support)
    v_unmatched_count := find_wb_unmatched_rows(p_user_id, v_combined_report_id);
    
    -- 8. Get unmatched sample
    IF v_unmatched_count > 0 THEN
        SELECT get_wb_unmatched_sample(p_user_id, v_combined_report_id, 10) INTO v_unmatched_sample;
    END IF;
    
    -- 9. Return results
    RETURN QUERY SELECT 
        v_processed_count,
        TRUE,
        v_unmatched_count,
        COALESCE(v_unmatched_sample, '[]'::JSONB);
END;
$$;

COMMENT ON FUNCTION process_wb_report_details(INTEGER, BIGINT) IS 
'Process Wildberries financial report details with unmatched rows via find_wb_unmatched_rows.';

COMMIT;