-- ============================================================================
-- Migration: fix_report_totals_logistics_correction_sign
-- Description: Change logistics_correction sign from '+' to '-' in report_totals
-- ============================================================================

BEGIN;

-- 1. Обновить функцию update_report_totals
DROP FUNCTION IF EXISTS update_report_totals(INTEGER, BIGINT);

CREATE OR REPLACE FUNCTION update_report_totals(
    p_user_id INTEGER,
    p_report_id BIGINT
)
RETURNS VOID LANGUAGE plpgsql AS $$
DECLARE
    v_report_totals NUMERIC(15,2);
BEGIN
    -- Update product summary report_totals
    UPDATE wb_fi_report_product_summary
    SET report_totals = 
        COALESCE(for_pay, 0) 
        - COALESCE(payback_for_return, 0)
        - COALESCE(logistics_total, 0)
        - COALESCE(logistics_correction, 0)
        - COALESCE(advertising, 0)
        - COALESCE(storage, 0)
        - COALESCE(fines, 0)
        - COALESCE(acceptance, 0)
        - COALESCE(transit, 0)
        - COALESCE(disposal, 0)
        + COALESCE(loss_compensation, 0)
        + COALESCE(freewill_compensation, 0)
        - COALESCE(seller_tax, 0)
        - COALESCE(overheads, 0)
        - COALESCE(cost_price, 0)
    WHERE user_id = p_user_id AND report_id = p_report_id;
    
    -- Update summary report_totals
    SELECT 
        COALESCE(for_pay, 0) 
        - COALESCE(payback_for_return, 0)
        - COALESCE(logistics_total, 0)
        - COALESCE(logistics_correction, 0)
        - COALESCE(advertising, 0)
        - COALESCE(storage, 0)
        - COALESCE(fines, 0)
        - COALESCE(acceptance, 0)
        - COALESCE(transit, 0)
        - COALESCE(disposal, 0)
        + COALESCE(loss_compensation, 0)
        + COALESCE(freewill_compensation, 0)
        - COALESCE(seller_tax, 0)
        - COALESCE(overheads, 0)
        - COALESCE(cost_price, 0) INTO v_report_totals
    FROM wb_fi_report_summary
    WHERE user_id = p_user_id AND report_id = p_report_id;
    
    UPDATE wb_fi_report_summary
    SET report_totals = v_report_totals
    WHERE user_id = p_user_id AND report_id = p_report_id;
END;
$$;

COMMENT ON FUNCTION update_report_totals(INTEGER, BIGINT) IS 
'Update report_totals for both summary and product summary. logistics_correction is subtracted.';

COMMIT;