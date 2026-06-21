
BEGIN;

-- Удалить старые правила disposal
DELETE FROM wb_fi_processing_rules 
WHERE target_field = 'disposal';

-- Вставить правило с LIKE
INSERT INTO wb_fi_processing_rules (
    rule_name,
    like_pattern,
    like_field,
    action,
    target_field,
    amount_source,
    priority
) VALUES (
    'Утилизация (отчёт об утилизированном товаре)',
    'Отчет об утилизированном товаре%',
    'bonus_type_name',
    'add',
    'disposal',
    'deduction',
    65
);

COMMIT;

-- Rollback:
-- BEGIN;
-- DELETE FROM wb_fi_processing_rules WHERE target_field = 'disposal';
-- ALTER TABLE wb_fi_processing_rules DROP COLUMN IF EXISTS like_field;
-- COMMIT;