-- ============================================================================
-- Migration: set_default_values_for_localization
-- Description: Set default values for loctype and locale in localization table
-- ============================================================================

BEGIN;

-- Set default for loctype
ALTER TABLE localization 
ALTER COLUMN loctype SET DEFAULT 1;

-- Set default for locale
ALTER TABLE localization 
ALTER COLUMN locale SET DEFAULT 'RU';

COMMIT;

-- Rollback:
-- BEGIN;
-- ALTER TABLE localization ALTER COLUMN loctype DROP DEFAULT;
-- ALTER TABLE localization ALTER COLUMN locale DROP DEFAULT;
-- COMMIT;