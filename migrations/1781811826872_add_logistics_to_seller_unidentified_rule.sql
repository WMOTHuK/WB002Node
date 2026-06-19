-- ============================================================================
-- Migration: add_logistics_to_seller_unidentified_rule
-- Description: Add logistics rule for unidentified goods return to seller
-- ============================================================================

BEGIN;

-- Rule for logistics_to_seller_unidentified (unidentified goods return to seller)
INSERT INTO wb_fi_processing_rules (
    rule_name,
    bonus_type_name,
    action,
    target_field,
    amount_source,
    priority
) VALUES (
    'Логистика до продавца (неопознанный товар)',
    'Возврат неопознанного товара (К продавцу)',
    'add',
    'logistics_to_seller_unidentified',
    'delivery_service',
    58
);

COMMIT;

-- Rollback:
-- BEGIN;
-- DELETE FROM wb_fi_processing_rules 
-- WHERE target_field = 'logistics_to_seller_unidentified' 
--   AND bonus_type_name = 'Возврат неопознанного товара (К продавцу)';
-- COMMIT;