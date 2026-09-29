-- ============================================================================
-- Migration: update_for_payout_formula_with_penalty_sum
-- Description: Update for_payout formula - subtract penalty_sum from headers
-- ============================================================================

BEGIN;

DROP FUNCTION IF EXISTS update_report_totals(INTEGER, BIGINT);

CREATE OR REPLACE FUNCTION update_report_totals(
    p_user_id INTEGER,
    p_report_id BIGINT
)
RETURNS VOID LANGUAGE plpgsql AS $$
DECLARE
    v_report_totals NUMERIC(15,2);
    v_for_payout NUMERIC(15,2);
    v_penalty_sum NUMERIC(15,2);
    v_report_ids BIGINT[];
BEGIN
    -- Получить объединённые report_ids (тип 1 + тип 2)
    v_report_ids := get_combined_report_ids(p_user_id, p_report_id);
    
    -- Получить penalty_sum из заголовков обоих отчётов
    SELECT COALESCE(SUM(penalty_sum), 0) INTO v_penalty_sum
    FROM wb_fi_report_headers
    WHERE user_id = p_user_id
      AND report_id = ANY(v_report_ids);
    
    -- Update product summary report_totals
    UPDATE wb_fi_report_product_summary
    SET report_totals = 
        COALESCE(for_pay, 0) 
        + COALESCE(sales_correction, 0)
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
    
    -- Calculate report_totals and for_payout for summary
    SELECT 
        -- report_totals
        COALESCE(for_pay, 0) 
        + COALESCE(sales_correction, 0)
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
        - COALESCE(cost_price, 0),
        -- for_payout (NEW FORMULA)
        COALESCE(for_pay, 0) 
        + COALESCE(sales_correction, 0)
        + COALESCE(freewill_compensation, 0)
        - COALESCE(payback_for_return, 0)
        - COALESCE(storage, 0)
        - COALESCE(advertising, 0)
        - COALESCE(acceptance, 0)
        - COALESCE(logistics_total, 0)
        - COALESCE(logistics_correction, 0)
        - v_penalty_sum
    INTO v_report_totals, v_for_payout
    FROM wb_fi_report_summary
    WHERE user_id = p_user_id AND report_id = p_report_id;
    
    UPDATE wb_fi_report_summary
    SET 
        report_totals = v_report_totals,
        for_payout = v_for_payout
    WHERE user_id = p_user_id AND report_id = p_report_id;
END;
$$;

COMMENT ON FUNCTION update_report_totals(INTEGER, BIGINT) IS 
'Update report_totals and for_payout. Formula: for_pay + sales_correction + freewill_compensation - payback_for_return - storage - advertising - acceptance - logistics_total - logistics_correction - penalty_sum';

COMMIT;