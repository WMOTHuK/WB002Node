-- ============================================================================
-- Migration: create_find_paired_report_function
-- Description: Find paired report (type 2) with same date range
-- ============================================================================

BEGIN;

CREATE OR REPLACE FUNCTION get_combined_report_ids(
    p_user_id INTEGER,
    p_report_id BIGINT
)
RETURNS BIGINT[] LANGUAGE plpgsql AS $$
DECLARE
    v_report_ids BIGINT[];
    v_main_report_id BIGINT;
    v_paired_report_id BIGINT;
    v_main_report_type INTEGER;
BEGIN
    -- Get report_type of the main report
    SELECT report_type INTO v_main_report_type
    FROM wb_fi_report_headers
    WHERE user_id = p_user_id AND report_id = p_report_id;
    
    -- Find the type 1 report (use as main for summary)
    IF v_main_report_type = 1 THEN
        v_main_report_id := p_report_id;
    ELSE
        -- Find paired type 1 report with same dates
        SELECT h.report_id INTO v_main_report_id
        FROM wb_fi_report_headers h
        WHERE h.user_id = p_user_id
          AND h.report_type = 1
          AND h.date_from = (SELECT date_from FROM wb_fi_report_headers WHERE user_id = p_user_id AND report_id = p_report_id)
          AND h.date_to = (SELECT date_to FROM wb_fi_report_headers WHERE user_id = p_user_id AND report_id = p_report_id)
        LIMIT 1;
    END IF;
    
    -- If no type 1 found, use the passed report_id
    IF v_main_report_id IS NULL THEN
        v_main_report_id := p_report_id;
    END IF;
    
    -- Find paired type 2 report with same dates
    SELECT h.report_id INTO v_paired_report_id
    FROM wb_fi_report_headers h
    WHERE h.user_id = p_user_id
      AND h.report_type = 2
      AND h.date_from = (SELECT date_from FROM wb_fi_report_headers WHERE user_id = p_user_id AND report_id = v_main_report_id)
      AND h.date_to = (SELECT date_to FROM wb_fi_report_headers WHERE user_id = p_user_id AND report_id = v_main_report_id)
    LIMIT 1;
    
    -- Build array of report_ids
    v_report_ids := ARRAY[v_main_report_id];
    IF v_paired_report_id IS NOT NULL THEN
        v_report_ids := ARRAY[v_main_report_id, v_paired_report_id];
    END IF;
    
    RETURN v_report_ids;
END;
$$;

COMMENT ON FUNCTION get_combined_report_ids(INTEGER, BIGINT) IS 
'Returns array of report_ids to process together (type 1 + type 2 paired).';

COMMIT;