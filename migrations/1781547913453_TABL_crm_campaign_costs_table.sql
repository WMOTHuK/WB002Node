-- ============================================================================
-- Migration: create_crm_campaign_costs_table (without foreign key)
-- Description: Table for storing campaign cost records
-- ============================================================================

BEGIN;

-- Create table without foreign key constraint
CREATE TABLE IF NOT EXISTS crm_campaign_costs (
    upd_num         INTEGER NOT NULL,
    upd_time        TIMESTAMP NOT NULL,
    upd_sum         NUMERIC(15,2) NOT NULL DEFAULT 0,
    advert_id       INTEGER NOT NULL,
    payment_type    VARCHAR(100) NOT NULL,
    created_at      TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMP NOT NULL DEFAULT NOW(),
    
    -- Composite primary key
    CONSTRAINT crm_campaign_costs_pkey PRIMARY KEY (upd_num, upd_time)
);

-- Create indexes
CREATE INDEX idx_crm_campaign_costs_advert_id ON crm_campaign_costs(advert_id);
CREATE INDEX idx_crm_campaign_costs_upd_time ON crm_campaign_costs(upd_time);
CREATE INDEX idx_crm_campaign_costs_payment_type ON crm_campaign_costs(payment_type);
CREATE INDEX idx_crm_campaign_costs_advert_time ON crm_campaign_costs(advert_id, upd_time);

-- Add comments
COMMENT ON TABLE crm_campaign_costs IS 'Campaign cost records (expenses by payment type)';
COMMENT ON COLUMN crm_campaign_costs.upd_num IS 'Update number (part of composite key)';
COMMENT ON COLUMN crm_campaign_costs.upd_time IS 'Update timestamp (part of composite key)';
COMMENT ON COLUMN crm_campaign_costs.upd_sum IS 'Cost amount in currency';
COMMENT ON COLUMN crm_campaign_costs.advert_id IS 'Campaign ID (references crm_headers) - referential integrity managed by application';
COMMENT ON COLUMN crm_campaign_costs.payment_type IS 'Payment type (e.g., "Баланс", "Карта", etc.)';
COMMENT ON COLUMN crm_campaign_costs.created_at IS 'Record creation timestamp';
COMMENT ON COLUMN crm_campaign_costs.updated_at IS 'Last update timestamp';

-- Create trigger for updated_at
CREATE OR REPLACE FUNCTION update_crm_campaign_costs_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_crm_campaign_costs_updated_at
    BEFORE UPDATE ON crm_campaign_costs
    FOR EACH ROW
    EXECUTE FUNCTION update_crm_campaign_costs_updated_at();

COMMIT;

-- Rollback:
-- BEGIN;
-- DROP TRIGGER IF EXISTS trigger_crm_campaign_costs_updated_at ON crm_campaign_costs;
-- DROP FUNCTION IF EXISTS update_crm_campaign_costs_updated_at();
-- DROP TABLE IF EXISTS crm_campaign_costs;
-- COMMIT;