-- ============================================================================
-- Migration: add_updated_at_to_users_table
-- Description: Add updated_at column to users table
-- ============================================================================

BEGIN;

-- Add updated_at column
ALTER TABLE users 
ADD COLUMN IF NOT EXISTS updated_at TIMESTAMP DEFAULT NOW();

-- Add comment
COMMENT ON COLUMN users.updated_at IS 'Timestamp of last user record update';

-- Create trigger to auto-update updated_at
CREATE OR REPLACE FUNCTION update_users_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_users_updated_at
    BEFORE UPDATE ON users
    FOR EACH ROW
    EXECUTE FUNCTION update_users_updated_at();

COMMIT;

-- Rollback:
-- BEGIN;
-- DROP TRIGGER IF EXISTS trigger_users_updated_at ON users;
-- DROP FUNCTION IF EXISTS update_users_updated_at();
-- ALTER TABLE users DROP COLUMN IF EXISTS updated_at;
-- COMMIT;