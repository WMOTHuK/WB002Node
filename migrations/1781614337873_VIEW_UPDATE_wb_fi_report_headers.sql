-- ============================================================================
-- Migration: update_wb_fi_report_headers_view
-- Description: Add has_items column indicating if report has detail records
-- ============================================================================

BEGIN;

-- Update view with has_items column
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
    h.bank_payment_sum,
    EXISTS (
        SELECT 1 
        FROM wb_fi_report_details d 
        WHERE d.user_id = h.user_id 
          AND d.report_id = h.report_id
    ) AS has_items
FROM wb_fi_report_headers h
LEFT JOIN wb_fi_report_types t ON h.report_type = t.report_type
ORDER BY h.report_id DESC;

-- Add comment
COMMENT ON VIEW wb_fi_report_headers_view IS 'Wildberries financial report headers with formatted period, type name, and has_items flag';
COMMENT ON COLUMN wb_fi_report_headers_view.has_items IS 'True if report has detail records in wb_fi_report_details';

COMMIT;

-- Rollback:
-- BEGIN;
-- CREATE OR REPLACE VIEW wb_fi_report_headers_view AS ... (previous version without has_items);
-- COMMIT;