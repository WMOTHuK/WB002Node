-- ============================================================================
-- Migration: add_logistics_from_client_cancel_rule
-- Description: Add logistics rule for delivery from client on cancel
-- ============================================================================

BEGIN;

-- Rule for logistics_from_client_cancel (delivery from client on cancel)
INSERT INTO wb_fi_processing_rules (
    rule_name,
    bonus_type_name,
    action,
    target_field,
    amount_source,
    priority
) VALUES (
    'Логистика от клиента (отмена)',
    'От клиента при отмене',
    'add',
    'logistics_from_client_cancel',
    'delivery_service',
    53
);

COMMIT;

-- Rollback:
-- BEGIN;
-- DELETE FROM wb_fi_processing_rules 
-- WHERE target_field = 'logistics_from_client_cancel' 
--   AND bonus_type_name = 'От клиента при отмене';
-- COMMIT;