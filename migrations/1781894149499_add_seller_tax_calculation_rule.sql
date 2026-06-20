-- ============================================================================
-- Migration: add_seller_tax_calculation_rule
-- Description: Calculate seller_tax as revenue * seller_tax_rate / 100
-- ============================================================================

BEGIN;

-- Add seller_tax to excluded_fields if not already there
INSERT INTO wb_fi_excluded_fields (field_name, reason) VALUES
    ('seller_tax', 'Calculated separately: revenue * seller_tax_rate / 100')
ON CONFLICT (field_name) DO NOTHING;

COMMIT;

-- Rollback:
-- BEGIN;
-- DELETE FROM wb_fi_excluded_fields WHERE field_name = 'seller_tax';
-- COMMIT;