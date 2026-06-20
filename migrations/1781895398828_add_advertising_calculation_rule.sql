-- ============================================================================
-- Migration: add_advertising_calculation_rule
-- Description: Calculate advertising as sum of upd_sum from crm_campaign_costs
--              where upd_time is within report date range (inclusive)
-- ============================================================================

BEGIN;

-- Add advertising to excluded_fields if not already there
INSERT INTO wb_fi_excluded_fields (field_name, reason) VALUES
    ('advertising', 'Calculated separately: sum of upd_sum from crm_campaign_costs within report date range')
ON CONFLICT (field_name) DO NOTHING;

COMMIT;

-- Rollback:
-- BEGIN;
-- DELETE FROM wb_fi_excluded_fields WHERE field_name = 'advertising';
-- COMMIT;