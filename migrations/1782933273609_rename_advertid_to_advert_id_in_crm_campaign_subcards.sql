-- ============================================================================
-- Migration: rename_advertid_to_advert_id_in_crm_campaign_subcards
-- Description: Rename advertid to advert_id for consistency
-- ============================================================================

BEGIN;

-- Переименовать столбец
ALTER TABLE crm_campaign_subcards RENAME COLUMN advertid TO advert_id;

-- Обновить комментарий
COMMENT ON COLUMN crm_campaign_subcards.advert_id IS 'Campaign ID (references crm_headers)';

COMMIT;

-- Rollback:
-- BEGIN;
-- ALTER TABLE crm_campaign_subcards RENAME COLUMN advert_id TO advertid;
-- COMMIT;