-- ============================================================================
-- Migration: add_payback_for_return_rule
-- Description: Add rule for payback on returns
-- ============================================================================

BEGIN;

-- Rule for payback_for_return (return amount)
INSERT INTO wb_fi_processing_rules (
    rule_name,
    doc_type_name,
    action,
    target_field,
    amount_source,
    priority
) VALUES (
    'Возврат денег за возврат',
    'Возврат',
    'add',
    'payback_for_return',
    'for_pay',
    20
);

COMMIT;

-- Rollback:
-- BEGIN;
-- DELETE FROM wb_fi_processing_rules 
-- WHERE target_field = 'payback_for_return' 
--   AND doc_type_name = 'Возврат';
-- COMMIT;