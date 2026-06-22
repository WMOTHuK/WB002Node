-- ============================================================================
-- Migration: add_product_summary_to_excluded_fields
-- Description: Exclude product summary fields from rule-based processing
-- ============================================================================

BEGIN;

-- Insert product summary fields into excluded_fields
INSERT INTO wb_fi_excluded_fields (field_name, reason) VALUES
    ('nm_id', 'Product ID - used for grouping in product summary'),
    ('quantity', 'Calculated separately by calculate_wb_product_quantity_volume'),
    ('volume', 'Calculated separately by calculate_wb_product_quantity_volume')
ON CONFLICT (field_name) DO NOTHING;

-- Also add any other product-specific fields that shouldn't be processed by rules
INSERT INTO wb_fi_excluded_fields (field_name, reason) VALUES
    ('wb_fi_report_product_summary', 'Handled separately by product_summary functions')
ON CONFLICT (field_name) DO NOTHING;

COMMIT;

-- Rollback:
-- BEGIN;
-- DELETE FROM wb_fi_excluded_fields 
-- WHERE field_name IN ('nm_id', 'quantity', 'volume', 'wb_fi_report_product_summary');
-- COMMIT;