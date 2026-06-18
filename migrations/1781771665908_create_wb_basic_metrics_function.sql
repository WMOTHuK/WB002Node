-- ============================================================================
-- Migration: create_wb_basic_metrics_function
-- Description: Dynamic function that auto-discovers table structure using excluded_fields config
-- ============================================================================

BEGIN;

DROP FUNCTION IF EXISTS calculate_wb_basic_metrics(INTEGER, BIGINT);

CREATE OR REPLACE FUNCTION calculate_wb_basic_metrics(
    p_user_id INTEGER,
    p_report_id BIGINT
)
RETURNS JSONB LANGUAGE plpgsql AS $$
DECLARE
    v_metrics JSONB := '{}'::JSONB;
    v_field RECORD;
    v_sql TEXT;
    v_value NUMERIC(15,2);
BEGIN
    -- Get fields from summary table excluding configured fields
    FOR v_field IN 
        SELECT 
            c.column_name,
            c.data_type
        FROM information_schema.columns c
        LEFT JOIN wb_fi_excluded_fields e ON c.column_name = e.field_name AND e.is_active = TRUE
        WHERE c.table_name = 'wb_fi_report_summary'
          AND c.table_schema = 'public'
          AND e.field_name IS NULL  -- only include fields NOT in excluded table
        ORDER BY c.ordinal_position
    LOOP
        -- For each field, call wb_sum_by_rule
        v_sql := FORMAT(
            'SELECT wb_sum_by_rule($1, $2, %L, %L)',
            v_field.column_name,  -- target_field
            'for_pay'              -- source_field (default)
        );
        
        EXECUTE v_sql INTO v_value USING p_user_id, p_report_id;
        v_metrics := jsonb_set(v_metrics, ARRAY[v_field.column_name], to_jsonb(v_value));
    END LOOP;
    
    RETURN v_metrics;
END;
$$;

COMMENT ON FUNCTION calculate_wb_basic_metrics(INTEGER, BIGINT) IS 
'Dynamically calculates all metrics based on table structure minus excluded fields';

COMMIT;