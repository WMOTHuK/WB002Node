-- ============================================================================
-- Migration: add_transit_rule_for_delivery_services
-- Description: Add LIKE rule for transit delivery services
-- ============================================================================

BEGIN;

-- Rule for transit (delivery services of transit supplies)
INSERT INTO wb_fi_processing_rules (
    rule_name,
    like_pattern,
    action,
    target_field,
    amount_source,
    priority
) VALUES (
    'Транзит (Услуги доставки транзитных поставок)',
    'Услуги доставки транзитных поставок%',
    'add',
    'transit',
    'deduction',
    68
);

COMMIT;

-- Rollback:
-- BEGIN;
-- DELETE FROM wb_fi_processing_rules 
-- WHERE target_field = 'transit' 
--   AND like_pattern = 'Услуги доставки транзитных поставок%';
-- COMMIT;