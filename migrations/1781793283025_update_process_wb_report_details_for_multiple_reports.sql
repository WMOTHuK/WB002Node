-- ============================================================================
-- Migration: update_process_wb_report_details_for_multiple_reports
-- Description: Main processing function with combined report support
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
    
    -- 7. Find unmatched rows from combined reports
    INSERT INTO wb_fi_unmatched_rows (user_id, report_id, row_data, reason)
    SELECT 
        p_user_id,
        v_combined_report_id,
        to_jsonb(d.*),
        'No matching rule found'
    FROM wb_fi_report_details d
    LEFT JOIN wb_fi_processing_rules r ON 
        (r.doc_type_name IS NULL OR r.doc_type_name = d.doc_type_name)
        AND (r.seller_oper_name IS NULL OR r.seller_oper_name = d.seller_oper_name)
        AND (r.bonus_type_name IS NULL OR r.bonus_type_name = d.bonus_type_name)
        AND r.is_active = TRUE
    WHERE d.user_id = p_user_id 
      AND d.report_id = ANY(v_report_ids)
      AND r.id IS NULL;
    
    GET DIAGNOSTICS v_unmatched_count = ROW_COUNT;
    
    -- 8. Get unmatched sample
    IF v_unmatched_count > 0 THEN
        SELECT COALESCE(jsonb_agg(
            jsonb_build_object(
                'rrd_id', d.rrd_id,
                'doc_type_name', d.doc_type_name,
                'seller_oper_name', d.seller_oper_name,
                'bonus_type_name', d.bonus_type_name,
                'for_pay', d.for_pay,
                'delivery_service', d.delivery_service,
                'penalty', d.penalty
            )
        ), '[]'::JSONB) INTO v_unmatched_sample
        FROM (
            SELECT *
            FROM wb_fi_report_details d
            LEFT JOIN wb_fi_processing_rules r ON 
                (r.doc_type_name IS NULL OR r.doc_type_name = d.doc_type_name)
                AND (r.seller_oper_name IS NULL OR r.seller_oper_name = d.seller_oper_name)
                AND (r.bonus_type_name IS NULL OR r.bonus_type_name = d.bonus_type_name)
                AND r.is_active = TRUE
            WHERE d.user_id = p_user_id 
              AND d.report_id = ANY(v_report_ids)
              AND r.id IS NULL
            LIMIT 10
        ) d;
    END IF;
    
    -- 9. Return results
    RETURN QUERY SELECT 
        v_processed_count,
        TRUE,
        v_unmatched_count,
        COALESCE(v_unmatched_sample, '[]'::JSONB);
END;
$$;

COMMIT;