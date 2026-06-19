-- ============================================================================
-- Migration: update_wb_complex_fields_for_multiple_reports
-- Description: Update complex fields for multiple reports
-- ============================================================================

BEGIN;

DROP FUNCTION IF EXISTS update_wb_complex_fields(INTEGER, BIGINT);

CREATE OR REPLACE FUNCTION update_wb_complex_fields(
    p_user_id INTEGER,
    p_report_ids BIGINT[],
    p_summary_report_id BIGINT
)
RETURNS VOID LANGUAGE sql AS $$
    UPDATE wb_fi_report_summary
    SET 
        overheads = calculate_wb_overheads(p_user_id, p_report_ids),
        report_totals = calculate_wb_report_totals(p_user_id, p_report_ids),
        logistics_total = calculate_wb_logistics_total(p_user_id, p_report_ids)
    WHERE user_id = p_user_id AND report_id = p_summary_report_id;
$$;

COMMIT;