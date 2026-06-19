-- ============================================================================
-- Migration: create_user_tax_rates_table
-- Description: Table for storing user tax rates with time ranges
-- ============================================================================

BEGIN;

-- Create table
CREATE TABLE IF NOT EXISTS user_tax_rates (
    id              SERIAL PRIMARY KEY,
    user_id         INTEGER NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    seller_tax      NUMERIC(5,2) NOT NULL DEFAULT 6.00,
    vat_tax         NUMERIC(5,2) NOT NULL DEFAULT 0.00,
    valid_from      DATE NOT NULL,
    valid_to        DATE NOT NULL DEFAULT '9999-12-31',
    created_at      TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMP NOT NULL DEFAULT NOW(),
    
    -- Ensure valid_from <= valid_to
    CONSTRAINT user_tax_rates_check_dates CHECK (valid_from <= valid_to)
);

-- Create indexes for performance
CREATE INDEX idx_user_tax_rates_user_id ON user_tax_rates(user_id);
CREATE INDEX idx_user_tax_rates_valid_from ON user_tax_rates(valid_from);
CREATE INDEX idx_user_tax_rates_valid_to ON user_tax_rates(valid_to);
CREATE INDEX idx_user_tax_rates_user_dates ON user_tax_rates(user_id, valid_from, valid_to);

-- Create unique constraint to prevent overlapping periods
-- This uses btree which works with integer
CREATE UNIQUE INDEX idx_user_tax_rates_no_overlap 
ON user_tax_rates (user_id, valid_from)
WHERE valid_to = '9999-12-31';

-- Add comments
COMMENT ON TABLE user_tax_rates IS 'User tax rates with time ranges';
COMMENT ON COLUMN user_tax_rates.user_id IS 'User reference';
COMMENT ON COLUMN user_tax_rates.seller_tax IS 'Seller tax rate (default 6%)';
COMMENT ON COLUMN user_tax_rates.vat_tax IS 'VAT tax rate (default 0%)';
COMMENT ON COLUMN user_tax_rates.valid_from IS 'Date from which this rate is valid';
COMMENT ON COLUMN user_tax_rates.valid_to IS 'Date until which this rate is valid (default 9999-12-31)';

-- Create trigger for updated_at
CREATE OR REPLACE FUNCTION update_user_tax_rates_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_user_tax_rates_updated_at
    BEFORE UPDATE ON user_tax_rates
    FOR EACH ROW
    EXECUTE FUNCTION update_user_tax_rates_updated_at();

COMMIT;

-- Rollback:
-- BEGIN;
-- DROP TRIGGER IF EXISTS trigger_user_tax_rates_updated_at ON user_tax_rates;
-- DROP FUNCTION IF EXISTS update_user_tax_rates_updated_at();
-- DROP TABLE IF EXISTS user_tax_rates;
-- COMMIT;