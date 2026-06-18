-- ============================================================================
-- Migration: insert_wb_processing_rules_sales
-- Description: Add sales processing rules
-- ============================================================================

BEGIN;

-- Rule 1a: Revenue from sales (retail_amount → revenue)
INSERT INTO wb_fi_processing_rules (
    rule_name,
    seller_oper_name,
    action,
    target_field,
    amount_source,
    priority
) VALUES (
    'Выручка от продаж',
    'Продажа',
    'add',
    'revenue',
    'retail_amount',
    10
);

-- Rule 1b: For_pay from sales (for_pay → for_pay)
INSERT INTO wb_fi_processing_rules (
    rule_name,
    seller_oper_name,
    action,
    target_field,
    amount_source,
    priority
) VALUES (
    'К оплате от продаж',
    'Продажа',
    'add',
    'for_pay',
    'for_pay',
    11
);

COMMIT;

-- Rollback:
-- BEGIN;
-- DELETE FROM wb_fi_processing_rules 
-- WHERE rule_name IN ('Выручка от продаж', 'К оплате от продаж');
-- COMMIT;