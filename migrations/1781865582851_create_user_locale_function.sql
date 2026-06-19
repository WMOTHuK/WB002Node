-- ============================================================================
-- Migration: fix_update_user_locale_function
-- Description: Remove email column from function (column doesn't exist in users table)
-- ============================================================================

BEGIN;

DROP FUNCTION IF EXISTS update_user_locale(INTEGER, VARCHAR, INTEGER);

CREATE OR REPLACE FUNCTION update_user_locale(
    p_user_id INTEGER,
    p_locale VARCHAR(2),
    p_changed_by INTEGER DEFAULT NULL
)
RETURNS TABLE (
    id INTEGER,
    login VARCHAR,
    locale VARCHAR(2)
) LANGUAGE plpgsql AS $$
DECLARE
    v_old_locale VARCHAR(2);
BEGIN
    -- Validate locale
    IF p_locale NOT IN ('RU', 'EN', 'KZ', 'BY') THEN
        RAISE EXCEPTION 'Invalid locale: %. Allowed: RU, EN, KZ, BY', p_locale;
    END IF;
    
    -- Check if user exists and get old locale
    SELECT u.locale INTO v_old_locale
    FROM users u
    WHERE u.id = p_user_id;
    
    IF NOT FOUND THEN
        RAISE EXCEPTION 'User with id % not found', p_user_id;
    END IF;
    
    -- If same locale, return without changes
    IF v_old_locale = p_locale THEN
        RETURN QUERY
        SELECT u.id, u.login, u.locale
        FROM users u
        WHERE u.id = p_user_id;
        RETURN;
    END IF;
    
    -- Update locale
    UPDATE users u
    SET locale = p_locale
    WHERE u.id = p_user_id;
    
    -- Log change
    INSERT INTO user_locale_log (user_id, old_locale, new_locale, changed_by)
    VALUES (p_user_id, v_old_locale, p_locale, p_changed_by);
    
    -- Return updated user
    RETURN QUERY
    SELECT 
        u.id,
        u.login,
        u.locale
    FROM users u
    WHERE u.id = p_user_id;
END;
$$;

COMMENT ON FUNCTION update_user_locale(INTEGER, VARCHAR, INTEGER) IS 
'Safely updates user locale with validation and logging. Returns updated user record.';

COMMIT;