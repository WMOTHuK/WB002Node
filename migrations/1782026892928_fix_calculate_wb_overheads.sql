-- ============================================================================
-- Migration: fix_calculate_wb_overheads
-- Description: Fix overheads calculation - single pass per user
-- ============================================================================

BEGIN;

DROP FUNCTION IF EXISTS calculate_wb_overheads(INTEGER, BIGINT[]);

CREATE OR REPLACE FUNCTION calculate_wb_overheads(
    p_user_id INTEGER,
    p_report_ids BIGINT[]
)
RETURNS NUMERIC(15,2) LANGUAGE plpgsql AS $$
DECLARE
    v_total_overheads NUMERIC(15,2) := 0;
    v_date_from DATE;
    v_date_to DATE;
    v_current_date DATE;
    v_month_start DATE;
    v_month_end DATE;
    v_month_overheads NUMERIC(15,2);
    v_days_in_month INTEGER;
    v_days_in_report INTEGER;
    v_report RECORD;
BEGIN
    -- Loop through each report_id (should be only one)
    FOR v_report IN 
        SELECT DISTINCT report_id
        FROM wb_fi_report_details
        WHERE user_id = p_user_id AND report_id = ANY(p_report_ids)
    LOOP
        -- Get date range for this report
        SELECT date_from, date_to INTO v_date_from, v_date_to
        FROM wb_fi_report_headers
        WHERE user_id = p_user_id AND report_id = v_report.report_id;
        
        -- If no headers found, skip
        IF v_date_from IS NULL THEN
            CONTINUE;
        END IF;
        
        -- Loop through each month in the report period
        v_current_date := v_date_from;
        WHILE v_current_date <= v_date_to LOOP
            -- Get month boundaries
            v_month_start := date_trunc('month', v_current_date)::DATE;
            v_month_end := (date_trunc('month', v_current_date) + INTERVAL '1 month - 1 day')::DATE;
            
            -- Calculate days in this month that fall within the report period
            v_days_in_report := 
                LEAST(v_date_to, v_month_end) - GREATEST(v_date_from, v_month_start) + 1;
            
            -- Get total days in this month
            v_days_in_month := EXTRACT(DAY FROM (v_month_end + INTERVAL '1 day'))::INTEGER;
            
            -- Get monthly overhead for this month from fi_overheads
            SELECT COALESCE(SUM(amount), 0) INTO v_month_overheads
            FROM fi_overheads
            WHERE user_id = p_user_id
              AND month = v_month_start
              AND platform = 'wb';
            
            -- Debug output (remove after testing)
            RAISE NOTICE 'Month: %, days_in_report: %, days_in_month: %, monthly_overheads: %', 
                v_month_start, v_days_in_report, v_days_in_month, v_month_overheads;
            
            -- Calculate prorated amount for this month
            v_total_overheads := v_total_overheads + 
                (v_month_overheads / v_days_in_month) * v_days_in_report;
            
            -- Move to next month
            v_current_date := v_month_end + 1;
        END LOOP;
    END LOOP;
    
    RETURN ROUND(v_total_overheads, 2);
END;
$$;

COMMENT ON FUNCTION calculate_wb_overheads(INTEGER, BIGINT[]) IS 
'Calculate prorated overheads based on daily distribution across months.';

COMMIT;