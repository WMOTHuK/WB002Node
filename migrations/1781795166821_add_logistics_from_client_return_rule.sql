-- ============================================================================
-- Migration: add_logistics_from_client_return_rule
-- Description: Add logistics rule for delivery from client on return
-- ============================================================================

BEGIN;

-- Rule for logistics_from_client_return (delivery from client on return)
INSERT INTO wb_fi_processing_rules (
    rule_name,
    bonus_type_name,
    action,
    target_field,
    amount_source,
    priority
) VALUES (
    'Логистика от клиента (возврат)',
    'От клиента при возврате',
    'add',
    'logistics_from_client_return',
    'delivery_service',
    55
);

COMMIT;

-- Rollback:
-- BEGIN;
-- DELETE FROM wb_fi_processing_rules 
-- WHERE target_field = 'logistics_from_client_return' 
--   AND bonus_type_name = 'От клиента при возврате';
-- COMMIT;