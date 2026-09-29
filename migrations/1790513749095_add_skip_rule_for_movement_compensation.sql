-- ============================================================================
-- Migration: add_skip_rule_for_movement_compensation
-- Description: Skip rows with seller_oper_name = 'Возмещение издержек по перемещению и операционной обработке товара'
-- ============================================================================

BEGIN;

-- Rule to skip movement compensation rows (mark as processed, do nothing)
INSERT INTO wb_fi_processing_rules (
    rule_name,
    seller_oper_name,
    action,
    target_field,
    amount_source,
    priority
) VALUES (
    'Пропуск - Возмещение издержек по перемещению и операционной обработке товара',
    'Возмещение издержек по перемещению и операционной обработке товара',
    'skip',
    NULL,
    NULL,
    8
)
ON CONFLICT DO NOTHING;

COMMIT;

-- Rollback:
-- BEGIN;
-- DELETE FROM wb_fi_processing_rules 
-- WHERE seller_oper_name = 'Возмещение издержек по перемещению и операционной обработке товара';
-- COMMIT;