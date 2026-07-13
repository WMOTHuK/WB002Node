-- ============================================================================
-- Migration: create_ozon_accural_types_table
-- Description: Create lookup table for Ozon accrual types
-- ============================================================================

BEGIN;

-- Create table
CREATE TABLE IF NOT EXISTS ozon_accural_types (
    id          INTEGER PRIMARY KEY,
    name        VARCHAR(255) NOT NULL,
    description TEXT,
    created_at  TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Add comments
COMMENT ON TABLE ozon_accural_types IS 'Lookup table for Ozon accrual types';
COMMENT ON COLUMN ozon_accural_types.id IS 'Accrual type ID (int32)';
COMMENT ON COLUMN ozon_accural_types.name IS 'Accrual type name';
COMMENT ON COLUMN ozon_accural_types.description IS 'Accrual type description';

-- Create trigger for updated_at
CREATE OR REPLACE FUNCTION update_ozon_accural_types_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_ozon_accural_types_updated_at
    BEFORE UPDATE ON ozon_accural_types
    FOR EACH ROW
    EXECUTE FUNCTION update_ozon_accural_types_updated_at();

COMMIT;

-- Rollback:
-- BEGIN;
-- DROP TRIGGER IF EXISTS trigger_ozon_accural_types_updated_at ON ozon_accural_types;
-- DROP FUNCTION IF EXISTS update_ozon_accural_types_updated_at();
-- DROP TABLE IF EXISTS ozon_accural_types;
-- COMMIT;