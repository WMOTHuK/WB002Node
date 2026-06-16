-- ============================================================================
-- Migration: create_crm_campaign_costs_view
-- Description: View for campaign costs with formatted datetime
-- ============================================================================

BEGIN;

-- Create view
CREATE OR REPLACE VIEW crm_campaign_costs_view AS
SELECT 
    advert_id,
    TO_CHAR(upd_time, 'DD.MM.YYYY HH24:MI') AS upd_time,
    upd_num,
    payment_type,
    upd_sum
FROM crm_campaign_costs
ORDER BY advert_id, upd_time DESC;

-- Add comments
COMMENT ON VIEW crm_campaign_costs_view IS 'Campaign costs with formatted datetime (DD.MM.YYYY HH24:MI)';
COMMENT ON COLUMN crm_campaign_costs_view.advert_id IS 'Campaign ID';
COMMENT ON COLUMN crm_campaign_costs_view.upd_time IS 'Update timestamp formatted as DD.MM.YYYY HH24:MI';
COMMENT ON COLUMN crm_campaign_costs_view.upd_num IS 'Update number';
COMMENT ON COLUMN crm_campaign_costs_view.payment_type IS 'Payment type (e.g., "Баланс", "Карта")';
COMMENT ON COLUMN crm_campaign_costs_view.upd_sum IS 'Cost amount';

COMMIT;

-- Rollback:
-- BEGIN;
-- DROP VIEW IF EXISTS crm_campaign_costs_view;
-- COMMIT;