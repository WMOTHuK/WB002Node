-- ============================================================================
-- Migration: add_logistics_to_seller_callback_rule
-- Description: Add logistics rule for product return to seller by callback
-- ============================================================================

BEGIN;

-- Rule for logistics_to_seller_callback (product return to seller by callback)
INSERT INTO wb_fi_processing_rules (
    rule_name,
    bonus_type_name,
    action,
    target_field,
    amount_source,
    priority
) VALUES (
    'Логистика до продавца (по отзыву)',
    'Возврат товара продавцу по отзыву (К продавцу)',
    'add',
    'logistics_to_seller_callback',
    'delivery_service',
    56
);

COMMIT;

-- Rollback:
-- BEGIN;
-- DELETE FROM wb_fi_processing_rules 
-- WHERE target_field = 'logistics_to_seller_callback' 
--   AND bonus_type_name = 'Возврат товара продавцу по отзыву (К продавцу)';
-- COMMIT;