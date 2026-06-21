-- ============================================================================
-- Migration: add_skip_rule_for_pvz_compensation
-- Description: Skip rows with seller_oper_name = 'Возмещение за выдачу и возврат товаров на ПВЗ'
-- ============================================================================

BEGIN;

-- Rule to skip PVZ compensation rows (mark as processed, do nothing)
INSERT INTO wb_fi_processing_rules (
    rule_name,
    seller_oper_name,
    action,
    target_field,
    amount_source,
    priority
) VALUES (
    'Пропуск - Возмещение за выдачу и возврат товаров на ПВЗ',
    'Возмещение за выдачу и возврат товаров на ПВЗ',
    'skip',
    NULL,
    NULL,
    7
);

COMMIT;

-- Rollback:
-- BEGIN;
-- DELETE FROM wb_fi_processing_rules 
-- WHERE seller_oper_name = 'Возмещение за выдачу и возврат товаров на ПВЗ';
-- COMMIT;