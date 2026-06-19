-- ============================================================================
-- Migration: add_acceptance_rule
-- Description: Add rule for acceptance costs
-- ============================================================================

BEGIN;

-- Rule for acceptance (product processing)
INSERT INTO wb_fi_processing_rules (
    rule_name,
    seller_oper_name,
    action,
    target_field,
    amount_source,
    priority
) VALUES (
    'Приёмка (обработка товара)',
    'Обработка товара',
    'add',
    'acceptance',
    'paid_acceptance',
    60
);

COMMIT;

-- Rollback:
-- BEGIN;
-- DELETE FROM wb_fi_processing_rules 
-- WHERE target_field = 'acceptance' 
--   AND seller_oper_name = 'Обработка товара';
-- COMMIT;