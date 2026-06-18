-- ============================================================================
-- Migration: update_wb_basic_metrics_no_mapping
-- Description: Uses amount_source from rules, not hardcoded mapping
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
    v_value NUMERIC(15,2);
    v_source_field TEXT;
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
          AND e.field_name IS NULL
        ORDER BY c.ordinal_position
    LOOP
        -- Get amount_source from rules table (not hardcoded!)
        v_source_field := get_amount_source_for_target(v_field.column_name);
        
        -- If no rule found, skip this field (or use 'for_pay' as fallback)
        IF v_source_field IS NULL THEN
            v_source_field := 'for_pay';
        END IF;
        
        -- Call wb_sum_by_rule with source_field from rules
        v_value := wb_sum_by_rule(
            p_user_id, 
            p_report_id, 
            v_field.column_name, 
            v_source_field,
            'add'
        );
        
        v_metrics := jsonb_set(v_metrics, ARRAY[v_field.column_name], to_jsonb(v_value));
    END LOOP;
    
    RETURN v_metrics;
END;
$$;

COMMENT ON FUNCTION calculate_wb_basic_metrics(INTEGER, BIGINT) IS 
'Dynamically calculates all metrics using amount_source from rules table. No hardcoded mapping!';

COMMIT;