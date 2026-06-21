-- ============================================================================
-- Migration: update_rule_matching_with_like
-- Description: Update rule matching to support LIKE patterns
-- ============================================================================

BEGIN;

-- Обновить find_wb_unmatched_rows
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
        (
            -- Exact match for doc_type_name
            (r.doc_type_name IS NULL OR r.doc_type_name = d.doc_type_name)
            OR 
            -- LIKE pattern for doc_type_name
            (r.like_pattern IS NOT NULL AND d.doc_type_name LIKE r.like_pattern)
        )
        AND (
            -- Exact match for seller_oper_name
            (r.seller_oper_name IS NULL OR r.seller_oper_name = d.seller_oper_name)
            OR 
            -- LIKE pattern for seller_oper_name
            (r.like_pattern IS NOT NULL AND d.seller_oper_name LIKE r.like_pattern)
        )
        AND (
            -- Exact match for bonus_type_name
            (r.bonus_type_name IS NULL OR r.bonus_type_name = d.bonus_type_name)
            OR 
            -- LIKE pattern for bonus_type_name
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

-- Обновить wb_sum_by_rule
CREATE OR REPLACE FUNCTION wb_sum_by_rule(
    p_user_id INTEGER,
    p_report_ids BIGINT[],
    p_target_field TEXT,
    p_source_field TEXT,
    p_action TEXT DEFAULT 'add'
)
RETURNS NUMERIC(15,2) LANGUAGE plpgsql STABLE AS $$
DECLARE
    v_sql TEXT;
    v_result NUMERIC(15,2);
BEGIN
    -- Build dynamic SQL with LIKE support
    v_sql := FORMAT(
        'SELECT COALESCE(SUM(
            CASE WHEN r.action = %L AND r.target_field = %L 
            THEN (d.%I::NUMERIC) 
            ELSE 0 END
        ), 0)
        FROM wb_fi_report_details d
        LEFT JOIN wb_fi_processing_rules r ON 
            (
                (r.doc_type_name IS NULL OR r.doc_type_name = d.doc_type_name)
                OR 
                (r.like_pattern IS NOT NULL AND d.doc_type_name LIKE r.like_pattern)
            )
            AND (
                (r.seller_oper_name IS NULL OR r.seller_oper_name = d.seller_oper_name)
                OR 
                (r.like_pattern IS NOT NULL AND d.seller_oper_name LIKE r.like_pattern)
            )
            AND (
                (r.bonus_type_name IS NULL OR r.bonus_type_name = d.bonus_type_name)
                OR 
                (r.like_pattern IS NOT NULL AND d.bonus_type_name LIKE r.like_pattern)
            )
            AND r.is_active = TRUE
        WHERE d.user_id = %L 
          AND d.report_id = ANY(%L)',
        p_action,
        p_target_field,
        p_source_field,
        p_user_id,
        p_report_ids
    );
    
    EXECUTE v_sql INTO v_result;
    RETURN COALESCE(v_result, 0);
END;
$$;

COMMIT;