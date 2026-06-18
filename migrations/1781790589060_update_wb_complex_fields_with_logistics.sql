-- ============================================================================
-- Migration: update_wb_complex_fields_with_logistics
-- Description: Add logistics_total calculation to complex fields update
-- ============================================================================

BEGIN;

CREATE OR REPLACE FUNCTION update_wb_complex_fields(
    p_user_id INTEGER,
    p_report_id BIGINT
)
RETURNS VOID LANGUAGE sql AS $$
    UPDATE wb_fi_report_summary
    SET 
        overheads = calculate_wb_overheads(p_user_id, p_report_id),
        report_totals = calculate_wb_report_totals(p_user_id, p_report_id),
        logistics_total = calculate_wb_logistics_total(p_user_id, p_report_id)
    WHERE user_id = p_user_id AND report_id = p_report_id;
$$;

COMMENT ON FUNCTION update_wb_complex_fields(INTEGER, BIGINT) IS 
'Updates complex fields: overheads, report_totals, logistics_total';

COMMIT;