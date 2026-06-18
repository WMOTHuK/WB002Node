-- ============================================================================
-- Migration: create_wb_process_steps_functions
-- Description: Each step of processing as separate function
-- ============================================================================

BEGIN;

-- Step 1: Clear summary
CREATE OR REPLACE FUNCTION clear_wb_summary(
    p_user_id INTEGER,
    p_report_id BIGINT
)
RETURNS VOID LANGUAGE sql AS $$
    DELETE FROM wb_fi_report_summary 
    WHERE user_id = p_user_id AND report_id = p_report_id;
$$;

-- Step 2: Insert basic metrics
CREATE OR REPLACE FUNCTION insert_wb_basic_metrics(
    p_user_id INTEGER,
    p_report_id BIGINT,
    p_metrics JSONB
)
RETURNS VOID LANGUAGE plpgsql AS $$
DECLARE
    v_columns TEXT := '';
    v_values TEXT := '';
    v_field RECORD;
    v_sql TEXT;
BEGIN
    -- Build dynamic INSERT from JSON metrics
    FOR v_field IN 
        SELECT 
            column_name
        FROM information_schema.columns
        WHERE table_name = 'wb_fi_report_summary'
          AND table_schema = 'public'
          AND column_name NOT IN (
              SELECT field_name FROM wb_fi_excluded_fields WHERE is_active = TRUE
          )
        ORDER BY ordinal_position
    LOOP
        IF v_columns = '' THEN
            v_columns := v_field.column_name;
            v_values := FORMAT('(%L)', p_metrics->>v_field.column_name);
        ELSE
            v_columns := v_columns || ', ' || v_field.column_name;
            v_values := v_values || ', ' || FORMAT('(%L)', p_metrics->>v_field.column_name);
        END IF;
    END LOOP;
    
    v_sql := FORMAT(
        'INSERT INTO wb_fi_report_summary (user_id, report_id, %s) VALUES (%L, %L, %s)',
        v_columns, p_user_id, p_report_id, v_values
    );
    
    EXECUTE v_sql;
END;
$$;

-- Step 3: Update complex fields
CREATE OR REPLACE FUNCTION update_wb_complex_fields(
    p_user_id INTEGER,
    p_report_id BIGINT
)
RETURNS VOID LANGUAGE sql AS $$
    UPDATE wb_fi_report_summary
    SET 
        overheads = calculate_wb_overheads(p_user_id, p_report_id),
        report_totals = calculate_wb_report_totals(p_user_id, p_report_id)
    WHERE user_id = p_user_id AND report_id = p_report_id;
$$;

-- Step 4: Get processed count
CREATE OR REPLACE FUNCTION get_wb_processed_count(
    p_user_id INTEGER,
    p_report_id BIGINT
)
RETURNS INTEGER LANGUAGE sql AS $$
    SELECT COUNT(*)
    FROM wb_fi_report_details
    WHERE user_id = p_user_id AND report_id = p_report_id;
$$;

-- Step 5: Find unmatched rows
CREATE OR REPLACE FUNCTION find_wb_unmatched_rows(
    p_user_id INTEGER,
    p_report_id BIGINT
)
RETURNS INTEGER LANGUAGE plpgsql AS $$
DECLARE
    v_count INTEGER;
BEGIN
    INSERT INTO wb_fi_unmatched_rows (user_id, report_id, row_data, reason)
    SELECT 
        p_user_id,
        p_report_id,
        to_jsonb(d.*),
        'No matching rule found'
    FROM wb_fi_report_details d
    LEFT JOIN wb_fi_processing_rules r ON 
        (r.doc_type_name IS NULL OR r.doc_type_name = d.doc_type_name)
        AND (r.seller_oper_name IS NULL OR r.seller_oper_name = d.seller_oper_name)
        AND (r.bonus_type_name IS NULL OR r.bonus_type_name = d.bonus_type_name)
        AND r.is_active = TRUE
    WHERE d.user_id = p_user_id 
      AND d.report_id = p_report_id
      AND r.id IS NULL;
    
    GET DIAGNOSTICS v_count = ROW_COUNT;
    RETURN v_count;
END;
$$;

-- Step 6: Get unmatched sample
CREATE OR REPLACE FUNCTION get_wb_unmatched_sample(
    p_user_id INTEGER,
    p_report_id BIGINT,
    p_limit INTEGER DEFAULT 10
)
RETURNS JSONB LANGUAGE sql AS $$
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'rrd_id', d.rrd_id,
                'doc_type_name', d.doc_type_name,
                'seller_oper_name', d.seller_oper_name,
                'bonus_type_name', d.bonus_type_name,
                'for_pay', d.for_pay,
                'delivery_service', d.delivery_service,
                'penalty', d.penalty
            )
        ),
        '[]'::JSONB
    )
    FROM wb_fi_report_details d
    LEFT JOIN wb_fi_processing_rules r ON 
        (r.doc_type_name IS NULL OR r.doc_type_name = d.doc_type_name)
        AND (r.seller_oper_name IS NULL OR r.seller_oper_name = d.seller_oper_name)
        AND (r.bonus_type_name IS NULL OR r.bonus_type_name = d.bonus_type_name)
        AND r.is_active = TRUE
    WHERE d.user_id = p_user_id 
      AND d.report_id = p_report_id
      AND r.id IS NULL
    LIMIT p_limit;
$$;

COMMIT;