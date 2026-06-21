-- ============================================================================
-- Migration: recreate_wb_sum_by_rule
-- Description: Recreate wb_sum_by_rule function
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
                (r.bonus_type_name IS NOT NULL AND r.bonus_type_name = d.bonus_type_name)
                OR 
                (r.like_pattern IS NOT NULL AND d.bonus_type_name LIKE r.like_pattern)
                OR 
                (r.bonus_type_name IS NULL AND r.like_pattern IS NULL)
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