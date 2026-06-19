-- ============================================================================
-- Migration: update_complex_calculators_for_multiple_reports
-- Description: Update overheads, logistics_total, report_totals to support multiple reports
-- ============================================================================

BEGIN;

-- logistics_total
CREATE OR REPLACE FUNCTION calculate_wb_logistics_total(
    p_user_id INTEGER,
    p_report_ids BIGINT[]
)
RETURNS NUMERIC(15,2) LANGUAGE sql STABLE AS $$
    SELECT COALESCE(SUM(delivery_service::NUMERIC), 0)
    FROM wb_fi_report_details
    WHERE user_id = p_user_id 
      AND report_id = ANY(p_report_ids)
      AND (delivery_amount::NUMERIC > 0 OR return_amount::NUMERIC > 0);
$$;

-- overheads
CREATE OR REPLACE FUNCTION calculate_wb_overheads(
    p_user_id INTEGER,
    p_report_ids BIGINT[]
)
RETURNS NUMERIC(15,2) LANGUAGE sql STABLE AS $$
    SELECT COALESCE(SUM(
        delivery_service::NUMERIC + 
        paid_storage::NUMERIC + 
        paid_acceptance::NUMERIC
    ), 0)
    FROM wb_fi_report_details
    WHERE user_id = p_user_id 
      AND report_id = ANY(p_report_ids);
$$;

-- report_totals
CREATE OR REPLACE FUNCTION calculate_wb_report_totals(
    p_user_id INTEGER,
    p_report_ids BIGINT[]
)
RETURNS NUMERIC(15,2) LANGUAGE sql STABLE AS $$
    SELECT COALESCE(SUM(for_pay::NUMERIC), 0)
    FROM wb_fi_report_details
    WHERE user_id = p_user_id 
      AND report_id = ANY(p_report_ids);
$$;

COMMIT;