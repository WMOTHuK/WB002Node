-- ============================================================================
-- Migration: exclude_logistics_total_from_rules
-- Description: Exclude logistics_total from rule-based processing
-- ============================================================================

BEGIN;

INSERT INTO wb_fi_excluded_fields (field_name, reason) VALUES
    ('logistics_total', 'Calculated separately: sum of delivery_service where delivery_amount > 0 OR return_amount > 0');

COMMIT;

-- Rollback:
-- BEGIN;
-- DELETE FROM wb_fi_excluded_fields WHERE field_name = 'logistics_total';
-- COMMIT;