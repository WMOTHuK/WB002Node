-- ============================================================================
-- Migration: create_calculate_wb_advertising_function
-- Description: Calculate advertising as sum of upd_sum from crm_campaign_costs
--              where upd_time is within report date range (inclusive)
-- ============================================================================

BEGIN;

CREATE OR REPLACE FUNCTION calculate_wb_advertising(
    p_user_id INTEGER,
    p_report_id BIGINT
)
RETURNS NUMERIC(15,2) LANGUAGE sql STABLE AS $$
    SELECT COALESCE(SUM(upd_sum::NUMERIC), 0)
    FROM crm_campaign_costs c
    JOIN wb_fi_report_headers h ON 
        h.user_id = p_user_id 
        AND h.report_id = p_report_id
        AND c.upd_time >= h.date_from
        AND c.upd_time < (h.date_to + INTERVAL '1 day')
    WHERE c.advert_id IN (
        SELECT advert_id 
        FROM crm_headers 
        WHERE user_id = p_user_id
    );
$$;

COMMENT ON FUNCTION calculate_wb_advertising(INTEGER, BIGINT) IS 
'Calculates advertising as sum of upd_sum from crm_campaign_costs within report date range (inclusive).';

COMMIT;