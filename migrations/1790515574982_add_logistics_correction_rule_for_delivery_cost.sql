-- ============================================================================
-- Migration: add_logistics_correction_rule_for_delivery_cost
-- Description: Add rule for delivery cost correction
-- ============================================================================

BEGIN;

-- Rule for logistics_correction (delivery cost correction)
INSERT INTO wb_fi_processing_rules (
    rule_name,
    seller_oper_name,
    action,
    target_field,
    amount_source,
    priority
) VALUES (
    'Коррекция стоимости доставки',
    'Коррекция стоимости доставки',
    'add',
    'logistics_correction',
    'delivery_service',
    58
)
ON CONFLICT DO NOTHING;

COMMIT;

-- Rollback:
-- BEGIN;
-- DELETE FROM wb_fi_processing_rules 
-- WHERE target_field = 'logistics_correction' 
--   AND seller_oper_name = 'Коррекция стоимости доставки';
-- COMMIT;