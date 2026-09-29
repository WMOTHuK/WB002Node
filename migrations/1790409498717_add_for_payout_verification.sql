-- ============================================================================
-- Migration: add_for_payout_verification
-- Description: Add verification of for_payout against bank_payment_sum from headers
-- ============================================================================

BEGIN;

-- ============================================================================
-- 1. Функция сверки for_payout с bank_payment_sum
-- ============================================================================

CREATE OR REPLACE FUNCTION verify_for_payout_vs_bank_payment(
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
    v_bank_payment_sum NUMERIC(15,2);
    v_diff NUMERIC(15,2);
BEGIN
    -- Получить объединённые report_ids (тип 1 + тип 2)
    v_report_ids := get_combined_report_ids(p_user_id, p_report_id);
    v_combined_report_id := v_report_ids[1];
    
    -- Получить for_payout из summary
    SELECT COALESCE(for_payout, 0) INTO v_for_payout
    FROM wb_fi_report_summary
    WHERE user_id = p_user_id AND report_id = v_combined_report_id;
    
    -- Получить сумму bank_payment_sum из обоих отчётов
    SELECT COALESCE(SUM(bank_payment_sum), 0) INTO v_bank_payment_sum
    FROM wb_fi_report_headers
    WHERE user_id = p_user_id
      AND report_id = ANY(v_report_ids);
    
    -- Рассчитать разницу
    v_diff := v_for_payout - v_bank_payment_sum;
    
    -- Вернуть результат
    field := 'Сверка for_payout с bank_payment_sum';
    source_sum := v_for_payout;
    target_sum := v_bank_payment_sum;
    difference := v_diff;
    
    IF v_diff = 0 THEN
        comment := '✅ OK';
    ELSE
        comment := '❌ ОШИБКА: расхождение ' || v_diff::TEXT;
    END IF;
    
    RETURN NEXT;
END;
$$;

COMMENT ON FUNCTION verify_for_payout_vs_bank_payment(INTEGER, BIGINT) IS 
'Verifies for_payout against sum of bank_payment_sum from both reports (type 1 + type 2).';

-- ============================================================================
-- 2. Обновить verify_report_calculation
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
    
    -- PERFORM 3: (будет добавлена позже)
    -- RETURN QUERY
    -- SELECT * FROM verify_another_thing(p_user_id, p_report_id);
    
END;
$$;

COMMENT ON FUNCTION verify_report_calculation(INTEGER, BIGINT) IS 
'Main report verification function. Calls multiple verification functions.';

COMMIT;