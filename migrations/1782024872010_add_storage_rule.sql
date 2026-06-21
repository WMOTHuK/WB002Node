-- ============================================================================
-- Migration: add_storage_rule
-- Description: Add rule for storage costs (seller_oper_name = 'Хранение')
-- ============================================================================

BEGIN;

-- Rule for storage (storage costs)
INSERT INTO wb_fi_processing_rules (
    rule_name,
    seller_oper_name,
    action,
    target_field,
    amount_source,
    priority
) VALUES (
    'Хранение',
    'Хранение',
    'add',
    'storage',
    'paid_storage',
    60
);

COMMIT;

-- Rollback:
-- BEGIN;
-- DELETE FROM wb_fi_processing_rules 
-- WHERE target_field = 'storage' 
--   AND seller_oper_name = 'Хранение';
-- COMMIT;