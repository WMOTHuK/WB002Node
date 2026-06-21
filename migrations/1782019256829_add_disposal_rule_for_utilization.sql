-- ============================================================================
-- Migration: add_disposal_rule_for_utilization
-- Description: Add rule for disposal deduction from utilization report
-- ============================================================================

BEGIN;

-- Rule for disposal (utilization report)
INSERT INTO wb_fi_processing_rules (
    rule_name,
    bonus_type_name,
    action,
    target_field,
    amount_source,
    priority
) VALUES (
    'Утилизация (отчёт об утилизированном товаре)',
    'Отчет об утилизированном товаре (по складу)',
    'add',
    'disposal',
    'deduction',
    65
);

COMMIT;

-- Rollback:
-- BEGIN;
-- DELETE FROM wb_fi_processing_rules 
-- WHERE target_field = 'disposal' 
--   AND bonus_type_name = 'Отчет об утилизированном товаре (по складу)';
-- COMMIT;