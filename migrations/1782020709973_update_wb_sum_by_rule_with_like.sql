-- ============================================================================
-- Migration: update_wb_sum_by_rule_with_like
-- Description: Add LIKE support to wb_sum_by_rule
-- ============================================================================

BEGIN;

DROP FUNCTION IF EXISTS wb_sum_by_rule(INTEGER, BIGINT[], TEXT, TEXT, TEXT);

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
    v_sql := FORMAT(
        'SELECT COALESCE(SUM(
            CASE WHEN r.action = %L AND r.target_field = %L 
            THEN (d.%I::NUMERIC) 
            ELSE 0 END
        ), 0)
        FROM wb_fi_report_details d
        LEFT JOIN wb_fi_processing_rules r ON 
            (r.doc_type_name IS NULL OR r.doc_type_name = d.doc_type_name)
            AND (r.seller_oper_name IS NULL OR r.seller_oper_name = d.seller_oper_name)
            AND (
                -- Exact match for bonus_type_name
                (r.bonus_type_name IS NOT NULL AND r.bonus_type_name = d.bonus_type_name)
                OR 
                -- LIKE pattern for bonus_type_name (if rule has like_pattern)
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

COMMENT ON FUNCTION wb_sum_by_rule(INTEGER, BIGINT[], TEXT, TEXT, TEXT) IS 
'Universal function with LIKE support for bonus_type_name.';

COMMIT;