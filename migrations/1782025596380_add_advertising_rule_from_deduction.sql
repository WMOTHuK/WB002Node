-- ============================================================================
-- Migration: add_advertising_rule_from_deduction
-- Description: Add LIKE rule for advertising from WB Promotion services
-- ============================================================================

BEGIN;

-- 1. Удалить advertising из excluded_fields (если там было)
DELETE FROM wb_fi_excluded_fields 
WHERE field_name = 'advertising';

-- 2. Удалить старое правило для advertising (если было из crm_campaign_costs)
DELETE FROM wb_fi_processing_rules 
WHERE target_field = 'advertising';

-- 3. Добавить новое правило с LIKE для advertising
INSERT INTO wb_fi_processing_rules (
    rule_name,
    like_pattern,
    action,
    target_field,
    amount_source,
    priority
) VALUES (
    'Реклама (WB Продвижение)',
    'Оказание услуг «WB Продвижение»%',
    'add',
    'advertising',
    'deduction',
    40
);

COMMIT;

-- Rollback:
-- BEGIN;
-- DELETE FROM wb_fi_processing_rules WHERE target_field = 'advertising';
-- INSERT INTO wb_fi_processing_rules (...) VALUES (...);
-- COMMIT;