-- ============================================================================
-- Migration: add_freewill_compensation_rule
-- Description: Add rule for freewill compensation on returns
-- ============================================================================

BEGIN;

-- Rule for freewill_compensation (freewill compensation on return)
INSERT INTO wb_fi_processing_rules (
    rule_name,
    seller_oper_name,
    action,
    target_field,
    amount_source,
    priority
) VALUES (
    'Добровольная компенсация при возврате',
    'Добровольная компенсация при возврате',
    'add',
    'freewill_compensation',
    'for_pay',
    30
);

COMMIT;

-- Rollback:
-- BEGIN;
-- DELETE FROM wb_fi_processing_rules 
-- WHERE target_field = 'freewill_compensation' 
--   AND seller_oper_name = 'Добровольная компенсация при возврате';
-- COMMIT;