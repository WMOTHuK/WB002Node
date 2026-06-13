-- ============================================================================
-- Migration: create_crm_campaign_subcards_table (without FK to crm_headers)
-- ============================================================================

BEGIN;

-- Create table without separate id
CREATE TABLE IF NOT EXISTS crm_campaign_subcards (
    advertid    INTEGER NOT NULL,
    vendorcode  VARCHAR(10) NOT NULL,
    created_at  TIMESTAMP NOT NULL DEFAULT NOW(),
    PRIMARY KEY (advertid, vendorcode)
);

-- Add foreign key to goods only (skip FK to crm_headers due to composite PK)
ALTER TABLE crm_campaign_subcards 
ADD CONSTRAINT fk_campaign_subcards_vendorcode 
FOREIGN KEY (vendorcode) REFERENCES goods(vendorcode) ON DELETE CASCADE;

-- Create indexes
CREATE INDEX idx_campaign_subcards_advertid ON crm_campaign_subcards(advertid);
CREATE INDEX idx_campaign_subcards_vendorcode ON crm_campaign_subcards(vendorcode);

-- Add comments
COMMENT ON TABLE crm_campaign_subcards IS 'Campaign subcards (products linked to campaigns)';
COMMENT ON COLUMN crm_campaign_subcards.advertid IS 'Campaign ID (references crm_headers) - referential integrity managed by application';
COMMENT ON COLUMN crm_campaign_subcards.vendorcode IS 'Product vendor code (references goods)';
COMMENT ON COLUMN crm_campaign_subcards.created_at IS 'Timestamp when product was added to campaign';

COMMIT;