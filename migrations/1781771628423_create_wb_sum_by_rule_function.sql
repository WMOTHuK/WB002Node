-- ============================================================================
-- Migration: create_wb_sum_by_rule_function
-- Description: Universal function to sum any field by processing rules
-- ============================================================================

BEGIN;

DROP FUNCTION IF EXISTS wb_sum_by_rule(INTEGER, BIGINT, TEXT, TEXT, TEXT);

CREATE OR REPLACE FUNCTION wb_sum_by_rule(
    p_user_id INTEGER,
    p_report_id BIGINT,
    p_target_field TEXT,
    p_source_field TEXT DEFAULT 'for_pay',
    p_action TEXT DEFAULT 'add'
)
RETURNS NUMERIC(15,2) LANGUAGE sql STABLE AS $$
    SELECT COALESCE(SUM(
        CASE WHEN r.action = p_action AND r.target_field = p_target_field 
        THEN (d.for_pay::NUMERIC) 
        ELSE 0 END
    ), 0)
    FROM wb_fi_report_details d
    LEFT JOIN wb_fi_processing_rules r ON 
        (r.doc_type_name IS NULL OR r.doc_type_name = d.doc_type_name)
        AND (r.seller_oper_name IS NULL OR r.seller_oper_name = d.seller_oper_name)
        AND (r.bonus_type_name IS NULL OR r.bonus_type_name = d.bonus_type_name)
        AND r.is_active = TRUE
    WHERE d.user_id = p_user_id 
      AND d.report_id = p_report_id;
$$;

COMMENT ON FUNCTION wb_sum_by_rule(INTEGER, BIGINT, TEXT, TEXT, TEXT) IS 
'Universal function to sum any field by processing rules';

COMMIT;