-- ============================================================================
-- Migration: update_for_payout_formula_and_add_verification
-- Description: Update for_payout formula and add report_totals verification
-- ============================================================================

BEGIN;

-- ============================================================================
-- 1. Обновить формулу for_payout в update_report_totals
-- ============================================================================

DROP FUNCTION IF EXISTS update_report_totals(INTEGER, BIGINT);

CREATE OR REPLACE FUNCTION update_report_totals(
    p_user_id INTEGER,
    p_report_id BIGINT
)
RETURNS VOID LANGUAGE plpgsql AS $$
DECLARE
    v_report_totals NUMERIC(15,2);
    v_for_payout NUMERIC(15,2);
BEGIN
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
'Update report_totals and for_payout. Formula: for_pay + sales_correction + freewill_compensation - payback_for_return - storage - advertising - acceptance - logistics_total';

-- ============================================================================
-- 2. Функция сверки for_payout с report_totals
-- ============================================================================

CREATE OR REPLACE FUNCTION verify_for_payout_vs_report_totals(
    p_user_id INTEGER,
    p_report_id BIGINT
)
RETURNS TABLE (
    field TEXT,
    source_sum NUMERIC(15,2),
    target_sum NUMERIC(15,2),
    difference NUMERIC(15,2),
    comment TEXT
) LANGUAGE plpgsql AS $$
DECLARE
    v_report_ids BIGINT[];
    v_combined_report_id BIGINT;
    v_for_payout NUMERIC(15,2);
    v_seller_tax NUMERIC(15,2);
    v_overheads NUMERIC(15,2);
    v_cost_price NUMERIC(15,2);
    v_report_totals NUMERIC(15,2);
    v_calculated NUMERIC(15,2);
    v_diff NUMERIC(15,2);
BEGIN
    -- Получить объединённые report_ids
    v_report_ids := get_combined_report_ids(p_user_id, p_report_id);
    v_combined_report_id := v_report_ids[1];
    
    -- Получить данные из summary
    SELECT 
        COALESCE(for_payout, 0),
        COALESCE(seller_tax, 0),
        COALESCE(overheads, 0),
        COALESCE(cost_price, 0),
        COALESCE(report_totals, 0)
    INTO 
        v_for_payout,
        v_seller_tax,
        v_overheads,
        v_cost_price,
        v_report_totals
    FROM wb_fi_report_summary
    WHERE user_id = p_user_id AND report_id = v_combined_report_id;
    
    -- Рассчитать: for_payout - seller_tax - overheads - cost_price
    v_calculated := v_for_payout - v_seller_tax - v_overheads - v_cost_price;
    
    -- Рассчитать разницу
    v_diff := v_calculated - v_report_totals;
    
    -- Вернуть результат
    field := 'Сверка report_totals: (for_payout - seller_tax - overheads - cost_price) vs report_totals';
    source_sum := v_calculated;
    target_sum := v_report_totals;
    difference := v_diff;
    
    IF v_diff = 0 THEN
        comment := '✅ OK';
    ELSE
        comment := '❌ ОШИБКА: расхождение ' || v_diff::TEXT;
    END IF;
    
    RETURN NEXT;
END;
$$;

COMMENT ON FUNCTION verify_for_payout_vs_report_totals(INTEGER, BIGINT) IS 
'Verifies that (for_payout - seller_tax - overheads - cost_price) equals report_totals.';

-- ============================================================================
-- 3. Обновить verify_report_calculation
-- ============================================================================

DROP FUNCTION IF EXISTS verify_report_calculation(INTEGER, BIGINT);

CREATE OR REPLACE FUNCTION verify_report_calculation(
    p_user_id INTEGER,
    p_report_id BIGINT
)
RETURNS TABLE (
    field TEXT,
    source_sum NUMERIC(15,2),
    target_sum NUMERIC(15,2),
    difference NUMERIC(15,2),
    comment TEXT
) LANGUAGE plpgsql AS $$
BEGIN
    -- PERFORM 1: Сверка общего отчёта с суммой по товарам
    RETURN QUERY
    SELECT * FROM verify_summary_vs_products(p_user_id, p_report_id);
    
    -- PERFORM 2: Сверка for_payout с bank_payment_sum
    RETURN QUERY
    SELECT * FROM verify_for_payout_vs_bank_payment(p_user_id, p_report_id);
    
    -- PERFORM 3: Сверка (for_payout - seller_tax - overheads - cost_price) с report_totals
    RETURN QUERY
    SELECT * FROM verify_for_payout_vs_report_totals(p_user_id, p_report_id);
    
END;
$$;

COMMENT ON FUNCTION verify_report_calculation(INTEGER, BIGINT) IS 
'Main report verification function. Calls multiple verification functions.';

COMMIT;