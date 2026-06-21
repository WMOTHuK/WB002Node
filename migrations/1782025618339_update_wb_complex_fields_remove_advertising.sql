-- ============================================================================
-- Migration: update_wb_complex_fields_remove_advertising
-- Description: Remove advertising from complex fields calculation
-- ============================================================================

BEGIN;

DROP FUNCTION IF EXISTS update_wb_complex_fields(INTEGER, BIGINT[], BIGINT);

CREATE OR REPLACE FUNCTION update_wb_complex_fields(
    p_user_id INTEGER,
    p_report_ids BIGINT[],
    p_summary_report_id BIGINT
)
RETURNS VOID LANGUAGE plpgsql AS $$
BEGIN
    UPDATE wb_fi_report_summary
    SET 
        seller_tax = calculate_wb_seller_tax(p_user_id, p_summary_report_id),
        overheads = calculate_wb_overheads(p_user_id, p_report_ids),
        report_totals = calculate_wb_report_totals(p_user_id, p_report_ids),
        logistics_total = calculate_wb_logistics_total(p_user_id, p_report_ids)
        -- advertising теперь считается через правила, а не здесь
    WHERE user_id = p_user_id AND report_id = p_summary_report_id;
END;
$$;

COMMENT ON FUNCTION update_wb_complex_fields(INTEGER, BIGINT[], BIGINT) IS 
'Updates complex fields except advertising (now handled by rules)';

COMMIT;