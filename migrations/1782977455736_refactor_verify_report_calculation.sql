-- ============================================================================
-- Migration: refactor_verify_report_calculation
-- Description: Extract summary vs product summary verification into separate function
-- ============================================================================

BEGIN;

-- ============================================================================
-- 1. Функция для получения локализованного названия поля
-- ============================================================================

CREATE OR REPLACE FUNCTION get_column_localization_by_user_id(
    p_user_id INTEGER,
    p_colname TEXT
)
RETURNS TEXT LANGUAGE sql STABLE AS $$
    SELECT value
    FROM localization
    WHERE loctype = 1
      AND colname = p_colname
      AND locale = COALESCE(
          (SELECT locale FROM users WHERE id = p_user_id),
          'RU'
      );
$$;

COMMENT ON FUNCTION get_column_localization_by_user_id(INTEGER, TEXT) IS 
'Returns localized column name for a user.';

-- ============================================================================
-- 2. Функция сверки общего отчёта с суммой по товарам
-- ============================================================================

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
    FOR v_field IN 
        SELECT 
            column_name,
            data_type
        FROM information_schema.columns
        WHERE table_name = 'wb_fi_report_summary'
          AND table_schema = 'public'
          AND column_name NOT IN ('user_id', 'report_id', 'created_at', 'updated_at')
        ORDER BY ordinal_position
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
'Verifies summary vs product summary sums for all fields.';

-- ============================================================================
-- 3. Основная функция сверки отчёта
-- ============================================================================

CREATE OR REPLACE FUNCTION verify_report_calculation(
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
BEGIN
    -- PERFORM 1: Сверка общего отчёта с суммой по товарам
    RETURN QUERY
    SELECT * FROM verify_summary_vs_products(p_user_id, p_report_id);
    
    -- PERFORM 2: (будет добавлена позже)
    -- RETURN QUERY
    -- SELECT * FROM verify_something_else(p_user_id, p_report_id);
    
    -- PERFORM 3: (будет добавлена позже)
    -- RETURN QUERY
    -- SELECT * FROM verify_another_thing(p_user_id, p_report_id);
    
END;
$$;

COMMENT ON FUNCTION verify_report_calculation(INTEGER, BIGINT) IS 
'Main report verification function. Calls multiple verification functions.';

COMMIT;