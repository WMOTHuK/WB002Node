-- ============================================================================
-- Migration: update_get_user_settings_function
-- Description: Update function with renamed columns
-- ============================================================================

BEGIN;

DROP FUNCTION IF EXISTS get_user_settings(INTEGER, DATE);

CREATE OR REPLACE FUNCTION get_user_settings(
    p_user_id INTEGER,
    p_date DATE DEFAULT CURRENT_DATE
)
RETURNS TABLE (
    user_id INTEGER,
    login VARCHAR,
    locale VARCHAR(2),
    seller_tax_rate NUMERIC(5,2),
    vat_tax_rate NUMERIC(5,2),
    valid_from DATE,
    valid_to DATE
) LANGUAGE sql STABLE AS $$
    SELECT 
        u.id,
        u.login,
        u.locale,
        COALESCE(t.seller_tax_rate, 6.00) AS seller_tax_rate,
        COALESCE(t.vat_tax_rate, 0.00) AS vat_tax_rate,
        COALESCE(t.valid_from, '1900-01-01'::DATE) AS valid_from,
        COALESCE(t.valid_to, '9999-12-31'::DATE) AS valid_to
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