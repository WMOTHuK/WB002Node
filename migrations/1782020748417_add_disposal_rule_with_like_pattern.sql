-- ============================================================================
-- Migration: add_disposal_rule_with_like_pattern
-- Description: Add disposal rule with LIKE pattern for bonus_type_name
-- ============================================================================

BEGIN;

-- Удалить старые правила disposal
DELETE FROM wb_fi_processing_rules 
WHERE target_field = 'disposal';

-- Добавить правило с LIKE
INSERT INTO wb_fi_processing_rules (
    rule_name,
    like_pattern,
    action,
    target_field,
    amount_source,
    priority
) VALUES (
    'Утилизация (отчёт об утилизированном товаре)',
    'Отчет об утилизированном товаре%',
    'add',
    'disposal',
    'deduction',
    65
);

COMMIT;

-- Rollback:
-- BEGIN;
-- DELETE FROM wb_fi_processing_rules WHERE target_field = 'disposal';
-- COMMIT;