-- ============================================================================
-- Migration: add_logistics_correction_rule
-- Description: Add logistics correction rule
-- ============================================================================

BEGIN;

-- Rule for logistics_correction (logistics correction)
INSERT INTO wb_fi_processing_rules (
    rule_name,
    seller_oper_name,
    action,
    target_field,
    amount_source,
    priority
) VALUES (
    'Коррекция логистики',
    'Коррекция логистики',
    'add',
    'logistics_correction',
    'delivery_service',
    57
);

COMMIT;

-- Rollback:
-- BEGIN;
-- DELETE FROM wb_fi_processing_rules 
-- WHERE target_field = 'logistics_correction' 
--   AND seller_oper_name = 'Коррекция логистики';
-- COMMIT;