-- ============================================================================
-- Migration: add_fines_for_storage_penalty_rule
-- Description: Add rule for storage penalty on returns at pickup points
-- ============================================================================

BEGIN;

-- Rule for fines (storage penalty for returns at pickup points over 3 days)
INSERT INTO wb_fi_processing_rules (
    rule_name,
    bonus_type_name,
    action,
    target_field,
    amount_source,
    priority
) VALUES (
    'Штраф за хранение возвратов на ПВЗ более 3 дней',
    'Платное хранение возвратов на ПВЗ более 3 дней',
    'add',
    'fines',
    'penalty',
    35
);

COMMIT;

-- Rollback:
-- BEGIN;
-- DELETE FROM wb_fi_processing_rules 
-- WHERE target_field = 'fines' 
--   AND bonus_type_name = 'Платное хранение возвратов на ПВЗ более 3 дней';
-- COMMIT;