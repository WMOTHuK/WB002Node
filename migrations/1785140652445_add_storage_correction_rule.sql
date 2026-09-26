-- ============================================================================
-- Migration: add_storage_correction_rule
-- Description: Add rule for storage correction (seller_oper_name = 'Коррекция хранения')
-- ============================================================================

BEGIN;

-- Rule for storage correction
INSERT INTO wb_fi_processing_rules (
    rule_name,
    seller_oper_name,
    action,
    target_field,
    amount_source,
    priority
) VALUES (
    'Коррекция хранения',
    'Коррекция хранения',
    'add',
    'storage',
    'paid_storage',
    61
);

COMMIT;

-- Rollback:
-- BEGIN;
-- DELETE FROM wb_fi_processing_rules 
-- WHERE target_field = 'storage' 
--   AND seller_oper_name = 'Коррекция хранения';
-- COMMIT;