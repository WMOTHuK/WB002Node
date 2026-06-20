-- ============================================================================
-- Migration: alter_crm_campaign_costs_primary_key
-- Description: Add advert_id to primary key for crm_campaign_costs
-- ============================================================================

BEGIN;

-- Drop existing primary key
ALTER TABLE crm_campaign_costs DROP CONSTRAINT IF EXISTS crm_campaign_costs_pkey;

-- Add composite primary key with advert_id
ALTER TABLE crm_campaign_costs 
ADD CONSTRAINT crm_campaign_costs_pkey 
PRIMARY KEY (upd_num, upd_time, advert_id);

-- Remove old unique index if exists
DROP INDEX IF EXISTS crm_campaign_costs_upd_num_upd_time_key;

COMMIT;

-- Rollback:
-- BEGIN;
-- ALTER TABLE crm_campaign_costs DROP CONSTRAINT crm_campaign_costs_pkey;
-- ALTER TABLE crm_campaign_costs ADD PRIMARY KEY (upd_num, upd_time);
-- COMMIT;