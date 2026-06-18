-- ============================================================================
-- Migration: create_get_amount_source_function
-- Description: Get amount_source from rules for a given target_field
-- ============================================================================

BEGIN;

CREATE OR REPLACE FUNCTION get_amount_source_for_target(
    p_target_field TEXT
)
RETURNS TEXT LANGUAGE sql STABLE AS $$
    SELECT amount_source
    FROM wb_fi_processing_rules
    WHERE target_field = p_target_field
      AND is_active = TRUE
    ORDER BY priority
    LIMIT 1;
$$;

COMMENT ON FUNCTION get_amount_source_for_target(TEXT) IS 
'Returns amount_source from the highest priority active rule for a given target_field.';

COMMIT;