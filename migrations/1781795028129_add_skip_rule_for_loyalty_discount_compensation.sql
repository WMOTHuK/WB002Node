-- ============================================================================
-- Migration: add_skip_rule_for_loyalty_discount_compensation
-- Description: Skip rows with seller_oper_name = 'Компенсация скидки по программе лояльности'
-- ============================================================================

BEGIN;

-- Rule to skip loyalty discount compensation rows (mark as processed, do nothing)
INSERT INTO wb_fi_processing_rules (
    rule_name,
    seller_oper_name,
    action,
    target_field,
    amount_source,
    priority
) VALUES (
    'Пропуск - Компенсация скидки по программе лояльности',
    'Компенсация скидки по программе лояльности',
    'skip',
    NULL,
    NULL,
    6
);

COMMIT;

-- Rollback:
-- BEGIN;
-- DELETE FROM wb_fi_processing_rules 
-- WHERE seller_oper_name = 'Компенсация скидки по программе лояльности';
-- COMMIT;