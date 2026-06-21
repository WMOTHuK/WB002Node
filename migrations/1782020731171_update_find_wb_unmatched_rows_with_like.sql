-- ============================================================================
-- Migration: update_find_wb_unmatched_rows_with_like
-- Description: Add LIKE support to unmatched rows detection
-- ============================================================================

BEGIN;

CREATE OR REPLACE FUNCTION find_wb_unmatched_rows(
    p_user_id INTEGER,
    p_report_id BIGINT
)
RETURNS INTEGER LANGUAGE plpgsql AS $$
DECLARE
    v_count INTEGER;
BEGIN
    -- Delete existing unmatched rows for this report
    DELETE FROM wb_fi_unmatched_rows 
    WHERE user_id = p_user_id AND report_id = p_report_id;
    
    -- Insert new unmatched rows with LIKE support
    INSERT INTO wb_fi_unmatched_rows (user_id, report_id, row_data, reason)
    SELECT 
        p_user_id,
        p_report_id,
        to_jsonb(d.*),
        'No matching rule found'
    FROM wb_fi_report_details d
    LEFT JOIN wb_fi_processing_rules r ON 
        (r.doc_type_name IS NULL OR r.doc_type_name = d.doc_type_name)
        AND (r.seller_oper_name IS NULL OR r.seller_oper_name = d.seller_oper_name)
        AND (
            (r.bonus_type_name IS NOT NULL AND r.bonus_type_name = d.bonus_type_name)
            OR 
            (r.like_pattern IS NOT NULL AND d.bonus_type_name LIKE r.like_pattern)
        )
        AND r.is_active = TRUE
    WHERE d.user_id = p_user_id 
      AND d.report_id = p_report_id
      AND r.id IS NULL;
    
    GET DIAGNOSTICS v_count = ROW_COUNT;
    RETURN v_count;
END;
$$;

COMMIT;