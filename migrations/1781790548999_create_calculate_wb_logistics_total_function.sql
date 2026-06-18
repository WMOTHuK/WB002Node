-- ============================================================================
-- Migration: create_calculate_wb_logistics_total_function
-- Description: Calculate logistics_total as sum of delivery_service 
--              where delivery_amount > 0 OR return_amount > 0
-- ============================================================================

BEGIN;

CREATE OR REPLACE FUNCTION calculate_wb_logistics_total(
    p_user_id INTEGER,
    p_report_id BIGINT
)
RETURNS NUMERIC(15,2) LANGUAGE sql STABLE AS $$
    SELECT COALESCE(SUM(delivery_service::NUMERIC), 0)
    FROM wb_fi_report_details
    WHERE user_id = p_user_id 
      AND report_id = p_report_id
      AND (delivery_amount::NUMERIC > 0 OR return_amount::NUMERIC > 0);
$$;

COMMENT ON FUNCTION calculate_wb_logistics_total(INTEGER, BIGINT) IS 
'Calculates total logistics: sum of delivery_service where delivery_amount > 0 OR return_amount > 0';

COMMIT;