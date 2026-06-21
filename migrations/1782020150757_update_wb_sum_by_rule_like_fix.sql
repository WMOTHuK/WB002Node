-- ============================================================================
-- Migration: update_wb_sum_by_rule_like_fix
-- Description: Fix LIKE logic to avoid catching all rows
-- ============================================================================

BEGIN;

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
            (
                -- doc_type_name: exact match OR LIKE
                (
                    (r.doc_type_name IS NOT NULL AND r.doc_type_name = d.doc_type_name)
                    OR 
                    (r.like_pattern IS NOT NULL AND r.like_field = ''doc_type_name'' AND d.doc_type_name LIKE r.like_pattern)
                )
                OR
                -- if both are NULL, match everything (catch-all rule)
                (r.doc_type_name IS NULL AND r.like_pattern IS NULL)
            )
            AND (
                -- seller_oper_name: exact match OR LIKE
                (
                    (r.seller_oper_name IS NOT NULL AND r.seller_oper_name = d.seller_oper_name)
                    OR 
                    (r.like_pattern IS NOT NULL AND r.like_field = ''seller_oper_name'' AND d.seller_oper_name LIKE r.like_pattern)
                )
                OR
                -- if both are NULL, match everything
                (r.seller_oper_name IS NULL AND r.like_pattern IS NULL)
            )
            AND (
                -- bonus_type_name: exact match OR LIKE
                (
                    (r.bonus_type_name IS NOT NULL AND r.bonus_type_name = d.bonus_type_name)
                    OR 
                    (r.like_pattern IS NOT NULL AND r.like_field = ''bonus_type_name'' AND d.bonus_type_name LIKE r.like_pattern)
                )
                OR
                -- if both are NULL, match everything
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

-- Обновить find_wb_unmatched_rows
CREATE OR REPLACE FUNCTION find_wb_unmatched_rows(
    p_user_id INTEGER,
    p_report_id BIGINT
)
RETURNS INTEGER LANGUAGE plpgsql AS $$
DECLARE
    v_count INTEGER;
BEGIN
    DELETE FROM wb_fi_unmatched_rows 
    WHERE user_id = p_user_id AND report_id = p_report_id;
    
    INSERT INTO wb_fi_unmatched_rows (user_id, report_id, row_data, reason)
    SELECT 
        p_user_id,
        p_report_id,
        to_jsonb(d.*),
        'No matching rule found'
    FROM wb_fi_report_details d
    LEFT JOIN wb_fi_processing_rules r ON 
        (
            (
                (r.doc_type_name IS NOT NULL AND r.doc_type_name = d.doc_type_name)
                OR 
                (r.like_pattern IS NOT NULL AND r.like_field = 'doc_type_name' AND d.doc_type_name LIKE r.like_pattern)
            )
            OR
            (r.doc_type_name IS NULL AND r.like_pattern IS NULL)
        )
        AND (
            (
                (r.seller_oper_name IS NOT NULL AND r.seller_oper_name = d.seller_oper_name)
                OR 
                (r.like_pattern IS NOT NULL AND r.like_field = 'seller_oper_name' AND d.seller_oper_name LIKE r.like_pattern)
            )
            OR
            (r.seller_oper_name IS NULL AND r.like_pattern IS NULL)
        )
        AND (
            (
                (r.bonus_type_name IS NOT NULL AND r.bonus_type_name = d.bonus_type_name)
                OR 
                (r.like_pattern IS NOT NULL AND r.like_field = 'bonus_type_name' AND d.bonus_type_name LIKE r.like_pattern)
            )
            OR
            (r.bonus_type_name IS NULL AND r.like_pattern IS NULL)
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