-- ============================================================================
-- Migration: fix_verify_summary_vs_products_missing_columns
-- Description: Skip columns that don't exist in product summary table
-- ============================================================================

BEGIN;

DROP FUNCTION IF EXISTS verify_summary_vs_products(INTEGER, BIGINT);

CREATE OR REPLACE FUNCTION verify_summary_vs_products(
    p_user_id INTEGER,
    p_report_id BIGINT
)
RETURNS TABLE (
    field TEXT,
    source_sum NUMERIC(15,2),
    target_sum NUMERIC(15,2),
    difference NUMERIC(15,2),
    comment TEXT
) LANGUAGE plpgsql AS $$
DECLARE
    v_field RECORD;
    v_source_val NUMERIC(15,2);
    v_target_val NUMERIC(15,2);
    v_diff NUMERIC(15,2);
    v_field_name TEXT;
BEGIN
    -- Loop through all columns in wb_fi_report_summary
    -- Only include columns that also exist in wb_fi_report_product_summary
    FOR v_field IN 
        SELECT 
            c.column_name,
            c.data_type
        FROM information_schema.columns c
        WHERE c.table_name = 'wb_fi_report_summary'
          AND c.table_schema = 'public'
          AND c.column_name NOT IN ('user_id', 'report_id', 'created_at', 'updated_at')
          AND EXISTS (
              SELECT 1 
              FROM information_schema.columns c2
              WHERE c2.table_name = 'wb_fi_report_product_summary'
                AND c2.table_schema = 'public'
                AND c2.column_name = c.column_name
          )
        ORDER BY c.ordinal_position
    LOOP
        -- Get localized field name
        v_field_name := get_column_localization_by_user_id(p_user_id, v_field.column_name);
        
        IF v_field_name IS NULL OR v_field_name = '' THEN
            v_field_name := v_field.column_name;
        END IF;
        
        -- Get source value from summary
        EXECUTE FORMAT(
            'SELECT COALESCE(%I, 0) FROM wb_fi_report_summary 
             WHERE user_id = %L AND report_id = %L',
            v_field.column_name,
            p_user_id,
            p_report_id
        ) INTO v_source_val;
        
        -- Get target value from product summary (sum of the same field)
        EXECUTE FORMAT(
            'SELECT COALESCE(SUM(%I), 0) FROM wb_fi_report_product_summary 
             WHERE user_id = %L AND report_id = %L',
            v_field.column_name,
            p_user_id,
            p_report_id
        ) INTO v_target_val;
        
        -- Calculate difference
        v_diff := v_source_val - v_target_val;
        
        -- Build result row
        field := 'Сверка детализации по ' || v_field_name;
        source_sum := v_source_val;
        target_sum := v_target_val;
        difference := v_diff;
        
        IF v_diff = 0 THEN
            comment := '✅ OK';
        ELSE
            comment := '❌ ОШИБКА: расхождение ' || v_diff::TEXT;
        END IF;
        
        RETURN NEXT;
    END LOOP;
END;
$$;

COMMENT ON FUNCTION verify_summary_vs_products(INTEGER, BIGINT) IS 
'Verifies summary vs product summary sums. Skips columns missing in product summary.';

COMMIT;