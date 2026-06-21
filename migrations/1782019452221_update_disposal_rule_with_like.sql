-- ============================================================================
-- Migration: update_disposal_rule_with_like
-- Description: Update disposal rule to use LIKE pattern
-- ============================================================================

BEGIN;

-- Удалить старое правило
DELETE FROM wb_fi_processing_rules 
WHERE target_field = 'disposal' 
  AND bonus_type_name = 'Отчет об утилизированном товаре (по складу)';

-- Вставить новое правило с LIKE
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
-- INSERT INTO wb_fi_processing_rules (...) VALUES (...);
-- COMMIT;