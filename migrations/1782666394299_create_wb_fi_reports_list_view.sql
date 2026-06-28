-- ============================================================================
-- Migration: create_wb_fi_reports_list_view
-- Description: View for getting report list with formatted labels
-- ============================================================================

BEGIN;

CREATE OR REPLACE VIEW wb_fi_reports_list_view AS
SELECT 
    user_id,
    report_id,
    date_from,
    date_to,
    CONCAT(TO_CHAR(date_from, 'DD.MM'), '-', TO_CHAR(date_to, 'DD.MM')) AS label,
    CONCAT(TO_CHAR(date_from, 'DD.MM.YYYY'), ' - ', TO_CHAR(date_to, 'DD.MM.YYYY')) AS full_label
FROM wb_fi_report_headers
WHERE report_type = 1
ORDER BY report_id DESC;

COMMENT ON VIEW wb_fi_reports_list_view IS 
'View for report list with formatted labels (DD.MM-DD.MM)';

COMMIT;