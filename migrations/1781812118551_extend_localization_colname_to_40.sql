-- ============================================================================
-- Migration: extend_localization_colname_to_40
-- Description: Extend colname column from VARCHAR(30) to VARCHAR(40)
-- ============================================================================

BEGIN;

-- Check for any data that would exceed the new length
DO $$
DECLARE
    v_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO v_count
    FROM localization 
    WHERE LENGTH(colname) > 40;
    
    IF v_count > 0 THEN
        RAISE NOTICE 'Found % records with colname longer than 40 characters.', v_count;
        -- If needed, you can truncate or handle them here
    END IF;
END $$;

-- Extend column length
ALTER TABLE localization 
ALTER COLUMN colname TYPE VARCHAR(40);

COMMIT;

-- Rollback:
-- BEGIN;
-- ALTER TABLE localization ALTER COLUMN colname TYPE VARCHAR(30);
-- COMMIT;