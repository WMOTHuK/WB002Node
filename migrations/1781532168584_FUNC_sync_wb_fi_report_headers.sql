-- ============================================================================
-- Миграция: FUNC_sync_wb_fi_report_headers
-- Дата: 2026-06-15T14:02:48.584Z
-- ============================================================================

CREATE OR REPLACE FUNCTION sync_wb_fi_report_headers(
    p_user_id INTEGER,
    p_reports JSONB
)
RETURNS TABLE (
    processed INTEGER,
    inserted INTEGER,
    updated INTEGER,
    errors INTEGER
) LANGUAGE plpgsql AS $$
DECLARE
    v_report RECORD;
    v_processed INTEGER := 0;
    v_inserted INTEGER := 0;
    v_updated INTEGER := 0;
    v_errors INTEGER := 0;
BEGIN
    FOR v_report IN 
        SELECT * FROM jsonb_to_recordset(p_reports) AS x(
            report_id BIGINT,
            seller_finance_name VARCHAR(255),
            date_from DATE,
            date_to DATE,
            create_date DATE,
            currency VARCHAR(3),
            report_type INTEGER,
            retail_amount_sum NUMERIC(15,2),
            for_pay_sum NUMERIC(15,2),
            avg_sale_percent NUMERIC(10,2),
            delivery_service_sum NUMERIC(15,2),
            paid_storage_sum NUMERIC(15,2),
            paid_acceptance_sum NUMERIC(15,2),
            deduction_sum NUMERIC(15,2),
            penalty_sum NUMERIC(15,2),
            additional_payment_sum NUMERIC(15,2),
            cashback_amount_sum NUMERIC(15,2),
            cashback_discount_sum NUMERIC(15,2),
            cashback_commission_change_sum NUMERIC(15,2),
            payment_schedule VARCHAR(10),
            bank_payment_sum NUMERIC(15,2)
        )
    LOOP
        v_processed := v_processed + 1;
        
        BEGIN
            INSERT INTO wb_fi_report_headers (
                user_id, report_id, seller_finance_name, date_from, date_to,
                create_date, currency, report_type, retail_amount_sum, for_pay_sum,
                avg_sale_percent, delivery_service_sum, paid_storage_sum,
                paid_acceptance_sum, deduction_sum, penalty_sum, additional_payment_sum,
                cashback_amount_sum, cashback_discount_sum, cashback_commission_change_sum,
                payment_schedule, bank_payment_sum
            ) VALUES (
                p_user_id, v_report.report_id, v_report.seller_finance_name,
                v_report.date_from, v_report.date_to, v_report.create_date,
                COALESCE(v_report.currency, 'RUB'), v_report.report_type,
                COALESCE(v_report.retail_amount_sum, 0), COALESCE(v_report.for_pay_sum, 0),
                COALESCE(v_report.avg_sale_percent, 0), COALESCE(v_report.delivery_service_sum, 0),
                COALESCE(v_report.paid_storage_sum, 0), COALESCE(v_report.paid_acceptance_sum, 0),
                COALESCE(v_report.deduction_sum, 0), COALESCE(v_report.penalty_sum, 0),
                COALESCE(v_report.additional_payment_sum, 0), COALESCE(v_report.cashback_amount_sum, 0),
                COALESCE(v_report.cashback_discount_sum, 0), COALESCE(v_report.cashback_commission_change_sum, 0),
                v_report.payment_schedule, COALESCE(v_report.bank_payment_sum, 0)
            )
            ON CONFLICT (user_id, report_id) 
            DO UPDATE SET 
                seller_finance_name = EXCLUDED.seller_finance_name,
                date_from = EXCLUDED.date_from,
                date_to = EXCLUDED.date_to,
                create_date = EXCLUDED.create_date,
                currency = EXCLUDED.currency,
                report_type = EXCLUDED.report_type,
                retail_amount_sum = EXCLUDED.retail_amount_sum,
                for_pay_sum = EXCLUDED.for_pay_sum,
                avg_sale_percent = EXCLUDED.avg_sale_percent,
                delivery_service_sum = EXCLUDED.delivery_service_sum,
                paid_storage_sum = EXCLUDED.paid_storage_sum,
                paid_acceptance_sum = EXCLUDED.paid_acceptance_sum,
                deduction_sum = EXCLUDED.deduction_sum,
                penalty_sum = EXCLUDED.penalty_sum,
                additional_payment_sum = EXCLUDED.additional_payment_sum,
                cashback_amount_sum = EXCLUDED.cashback_amount_sum,
                cashback_discount_sum = EXCLUDED.cashback_discount_sum,
                cashback_commission_change_sum = EXCLUDED.cashback_commission_change_sum,
                payment_schedule = EXCLUDED.payment_schedule,
                bank_payment_sum = EXCLUDED.bank_payment_sum,
                updated_at = NOW();
            
            v_inserted := v_inserted + 1;
        EXCEPTION WHEN OTHERS THEN
            v_errors := v_errors + 1;
        END;
    END LOOP;
    
    RETURN QUERY SELECT v_processed, v_inserted, v_updated, v_errors;
END;
$$;