-- ============================================================================
-- Migration: add_locale_to_users_table
-- Description: Add locale field to users table with default 'RU'
-- ============================================================================

BEGIN;

-- Add locale column
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS locale VARCHAR(2) DEFAULT 'RU';

-- Update existing records
UPDATE users 
SET locale = 'RU' 
WHERE locale IS NULL;

-- Add comment
COMMENT ON COLUMN users.locale IS 'User locale (RU, EN, etc.)';

COMMIT;

-- Rollback:
-- BEGIN;
-- ALTER TABLE users DROP COLUMN IF EXISTS locale;
-- COMMIT;