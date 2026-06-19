-- ============================================================================
-- Migration: rename_tax_columns_in_user_tax_rates
-- Description: Rename seller_tax → seller_tax_rate, vat_tax → vat_tax_rate
-- ============================================================================

BEGIN;

-- Rename columns in user_tax_rates table
ALTER TABLE user_tax_rates 
RENAME COLUMN seller_tax TO seller_tax_rate;

ALTER TABLE user_tax_rates 
RENAME COLUMN vat_tax TO vat_tax_rate;

-- Update comments
COMMENT ON COLUMN user_tax_rates.seller_tax_rate IS 'Seller tax rate (default 6%)';
COMMENT ON COLUMN user_tax_rates.vat_tax_rate IS 'VAT tax rate (default 0%)';

COMMIT;

-- Rollback:
-- BEGIN;
-- ALTER TABLE user_tax_rates RENAME COLUMN seller_tax_rate TO seller_tax;
-- ALTER TABLE user_tax_rates RENAME COLUMN vat_tax_rate TO vat_tax;
-- COMMIT;