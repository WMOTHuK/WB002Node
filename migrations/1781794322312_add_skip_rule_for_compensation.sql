-- ============================================================================
-- Migration: add_skip_rule_for_compensation
-- Description: Skip rows with seller_oper_name = 'Возмещение издержек по перевозке/по складским операциям с товаром'
-- ============================================================================

BEGIN;

-- Rule to skip compensation rows (mark as processed, do nothing)
INSERT INTO wb_fi_processing_rules (
    rule_name,
    seller_oper_name,
    action,
    target_field,
    amount_source,
    priority
) VALUES (
    'Пропуск - Возмещение издержек',
    'Возмещение издержек по перевозке/по складским операциям с товаром',
    'skip',
    NULL,
    NULL,
    5
);

COMMIT;

-- Rollback:
-- BEGIN;
-- DELETE FROM wb_fi_processing_rules 
-- WHERE seller_oper_name = 'Возмещение издержек по перевозке/по складским операциям с товаром';
-- COMMIT;