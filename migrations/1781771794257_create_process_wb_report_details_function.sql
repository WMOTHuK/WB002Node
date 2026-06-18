-- ============================================================================
-- Migration: create_process_wb_report_details_function
-- Description: Main processing function - orchestrates all steps
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
    v_metrics JSONB;
    v_processed_count INTEGER := 0;
    v_unmatched_count INTEGER := 0;
    v_unmatched_sample JSONB := '[]'::JSONB;
BEGIN
    -- Step 1: Clear existing summary
    PERFORM clear_wb_summary(p_user_id, p_report_id);
    
    -- Step 2: Calculate basic metrics
    v_metrics := calculate_wb_basic_metrics(p_user_id, p_report_id);
    
    -- Step 3: Insert basic metrics
    PERFORM insert_wb_basic_metrics(p_user_id, p_report_id, v_metrics);
    
    -- Step 4: Update complex fields
    PERFORM update_wb_complex_fields(p_user_id, p_report_id);
    
    -- Step 5: Get processed count
    v_processed_count := get_wb_processed_count(p_user_id, p_report_id);
    
    -- Step 6: Find unmatched rows
    v_unmatched_count := find_wb_unmatched_rows(p_user_id, p_report_id);
    
    -- Step 7: Get unmatched sample
    v_unmatched_sample := get_wb_unmatched_sample(p_user_id, p_report_id);
    
    -- Return results
    RETURN QUERY SELECT 
        v_processed_count,
        TRUE,
        v_unmatched_count,
        v_unmatched_sample;
END;
$$;

COMMENT ON FUNCTION process_wb_report_details(INTEGER, BIGINT) IS 
'Main processing function - orchestrates all steps';

COMMIT;