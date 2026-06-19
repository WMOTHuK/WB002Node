-- ============================================================================
-- Migration: fix_get_user_settings_final
-- Description: Completely avoid naming conflicts
-- ============================================================================

BEGIN;

DROP FUNCTION IF EXISTS get_user_settings(INTEGER, DATE);

CREATE OR REPLACE FUNCTION get_user_settings(
    p_user_id INTEGER,
    p_date DATE DEFAULT CURRENT_DATE
)
RETURNS TABLE (
    user_id INTEGER,
    user_login VARCHAR,
    user_locale VARCHAR(2),
    tax_seller_rate NUMERIC(5,2),
    tax_vat_rate NUMERIC(5,2),
    tax_valid_from DATE,
    tax_valid_to DATE
) LANGUAGE sql STABLE AS $$
    SELECT 
        u.id,
        u.login,
        u.locale,
        COALESCE(t.seller_tax_rate, 6.00)::NUMERIC(5,2),
        COALESCE(t.vat_tax_rate, 0.00)::NUMERIC(5,2),
        COALESCE(t.valid_from, '1900-01-01'::DATE),
        COALESCE(t.valid_to, '9999-12-31'::DATE)
    FROM users u
    LEFT JOIN user_tax_rates t ON 
        t.user_id = u.id 
        AND t.valid_from <= p_date 
        AND t.valid_to >= p_date
    WHERE u.id = p_user_id;
$$;

COMMENT ON FUNCTION get_user_settings(INTEGER, DATE) IS 
'Returns user settings with tax rates valid for specified date.';

COMMIT;