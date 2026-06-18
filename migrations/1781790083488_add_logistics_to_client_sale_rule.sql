-- ============================================================================
-- Migration: add_logistics_to_client_sale_rule
-- Description: Add logistics rule for delivery to client on sale
-- ============================================================================

BEGIN;

-- Rule for logistics_to_client_sale (delivery to client on sale)
INSERT INTO wb_fi_processing_rules (
    rule_name,
    bonus_type_name,
    action,
    target_field,
    amount_source,
    priority
) VALUES (
    'Логистика до клиента (продажа)',
    'К клиенту при продаже',
    'add',
    'logistics_to_client_sale',
    'delivery_service',
    50
);


-- Rollback:
-- BEGIN;
-- DELETE FROM wb_fi_processing_rules 
-- WHERE bonus_type_name = 'К клиенту при продаже' 
--   AND target_field IN ('logistics_to_client_sale');
-- COMMIT;