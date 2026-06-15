-- ============================================================================
-- Migration: create_wb_fi_report_headers_view
-- Description: View for Wildberries financial report headers with formatted period
-- ============================================================================

BEGIN;

-- Create view with ordering
CREATE OR REPLACE VIEW wb_fi_report_headers_view AS
SELECT 
    h.user_id,
    h.report_id,
    CONCAT('с ', TO_CHAR(h.date_from, 'DD.MM.YYYY'), ' по ', TO_CHAR(h.date_to, 'DD.MM.YYYY')) AS period,
    COALESCE(t.report_type_name, 'Неизвестный тип') AS report_type_name,
    h.retail_amount_sum,
    h.for_pay_sum,
    h.delivery_service_sum,
    h.paid_storage_sum,
    h.paid_acceptance_sum,
    h.deduction_sum,
    h.penalty_sum,
    h.bank_payment_sum
FROM wb_fi_report_headers h
LEFT JOIN wb_fi_report_types t ON h.report_type = t.report_type
ORDER BY h.report_id DESC;

-- Add comments
COMMENT ON VIEW wb_fi_report_headers_view IS 'View of Wildberries financial report headers with formatted period and type name, ordered by report_id descending';
COMMENT ON COLUMN wb_fi_report_headers_view.user_id IS 'User reference';
COMMENT ON COLUMN wb_fi_report_headers_view.report_id IS 'Unique report identifier';
COMMENT ON COLUMN wb_fi_report_headers_view.period IS 'Formatted period string (e.g., "с 08.06.2026 по 14.06.2026")';
COMMENT ON COLUMN wb_fi_report_headers_view.report_type_name IS 'Report type display name';
COMMENT ON COLUMN wb_fi_report_headers_view.retail_amount_sum IS 'Total retail amount';
COMMENT ON COLUMN wb_fi_report_headers_view.for_pay_sum IS 'Amount to be paid';
COMMENT ON COLUMN wb_fi_report_headers_view.delivery_service_sum IS 'Delivery service costs';
COMMENT ON COLUMN wb_fi_report_headers_view.paid_storage_sum IS 'Storage costs';
COMMENT ON COLUMN wb_fi_report_headers_view.paid_acceptance_sum IS 'Acceptance costs';
COMMENT ON COLUMN wb_fi_report_headers_view.deduction_sum IS 'Deductions amount';
COMMENT ON COLUMN wb_fi_report_headers_view.penalty_sum IS 'Penalties amount';
COMMENT ON COLUMN wb_fi_report_headers_view.bank_payment_sum IS 'Bank payment amount';

COMMIT;

-- Rollback:
-- BEGIN;
-- DROP VIEW IF EXISTS wb_fi_report_headers_view;
-- COMMIT;