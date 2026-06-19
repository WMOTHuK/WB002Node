-- ============================================================================
-- Migration: add_logistics_to_seller_defect_rule
-- Description: Add logistics rule for defect return to seller
-- ============================================================================

BEGIN;

-- Rule for logistics_to_seller_defect (defect return to seller)
INSERT INTO wb_fi_processing_rules (
    rule_name,
    bonus_type_name,
    action,
    target_field,
    amount_source,
    priority
) VALUES (
    'Логистика до продавца (брак)',
    'Возврат брака (К продавцу)',
    'add',
    'logistics_to_seller_defect',
    'delivery_service',
    54
);

COMMIT;

-- Rollback:
-- BEGIN;
-- DELETE FROM wb_fi_processing_rules 
-- WHERE target_field = 'logistics_to_seller_defect' 
--   AND bonus_type_name = 'Возврат брака (К продавцу)';
-- COMMIT;