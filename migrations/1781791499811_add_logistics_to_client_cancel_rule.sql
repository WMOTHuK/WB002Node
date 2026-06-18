-- ============================================================================
-- Migration: add_logistics_to_client_cancel_rule
-- Description: Add logistics rule for delivery to client on cancel
-- ============================================================================

BEGIN;

-- Rule for logistics_to_client_cancel (delivery to client on cancel)
INSERT INTO wb_fi_processing_rules (
    rule_name,
    bonus_type_name,
    action,
    target_field,
    amount_source,
    priority
) VALUES (
    'Логистика до клиента (отмена)',
    'К клиенту при отмене',
    'add',
    'logistics_to_client_cancel',
    'delivery_service',
    52
);

COMMIT;

-- Rollback:
-- BEGIN;
-- DELETE FROM wb_fi_processing_rules 
-- WHERE target_field = 'logistics_to_client_cancel' 
--   AND bonus_type_name = 'К клиенту при отмене';
-- COMMIT;