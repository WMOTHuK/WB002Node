-- ============================================================================
-- Migration: add_for_payout_column_and_calculation
-- Description: Add for_payout column to summary and view, calculate it
-- ============================================================================

BEGIN;

-- ============================================================================
-- 1. Добавить столбец for_payout в wb_fi_report_summary
-- ============================================================================

ALTER TABLE wb_fi_report_summary 
ADD COLUMN IF NOT EXISTS for_payout NUMERIC(15,2) DEFAULT 0;

COMMENT ON COLUMN wb_fi_report_summary.for_payout IS 
'Payout amount: for_pay - logistics_total - sales_correction - freewill_compensation - storage - advertising - acceptance';

-- ============================================================================
-- 2. Обновить update_report_totals (добавить расчёт for_payout)
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
        -- for_payout
        COALESCE(for_pay, 0) 
        - COALESCE(logistics_total, 0)
        - COALESCE(sales_correction, 0)
        - COALESCE(freewill_compensation, 0)
        - COALESCE(storage, 0)
        - COALESCE(advertising, 0)
        - COALESCE(acceptance, 0)
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
'Update report_totals and for_payout for summary and report_totals for product summary.';

-- ============================================================================
-- 3. Обновить wb_fi_report_summary_view
-- ============================================================================

DROP VIEW IF EXISTS wb_fi_report_summary_view CASCADE;

CREATE VIEW wb_fi_report_summary_view AS
SELECT 
    h.user_id,
    h.report_id,
    h.date_from,
    h.date_to,
    h.report_type,
    COALESCE(s.quantity, 0) AS quantity,
    COALESCE(s.volume, 0) AS volume,
    COALESCE(s.revenue, 0) AS revenue,
    COALESCE(s.for_pay, 0) AS for_pay,
    COALESCE(s.sales_correction, 0) AS sales_correction,
    COALESCE(s.for_payout, 0) AS for_payout,
    COALESCE(s.payback_for_return, 0) AS payback_for_return,
    COALESCE(s.logistics_total, 0) AS logistics_total,
    COALESCE(s.logistics_to_client_sale, 0) AS logistics_to_client_sale,
    COALESCE(s.logistics_to_client_cancel, 0) AS logistics_to_client_cancel,
    COALESCE(s.logistics_to_seller_callback, 0) AS logistics_to_seller_callback,
    COALESCE(s.logistics_to_seller_defect, 0) AS logistics_to_seller_defect,
    COALESCE(s.logistics_to_seller_unidentified, 0) AS logistics_to_seller_unidentified,
    COALESCE(s.logistics_from_client_cancel, 0) AS logistics_from_client_cancel,
    COALESCE(s.logistics_from_client_return, 0) AS logistics_from_client_return,
    COALESCE(s.logistics_correction, 0) AS logistics_correction,
    COALESCE(s.advertising, 0) AS advertising,
    COALESCE(s.storage, 0) AS storage,
    COALESCE(s.fines, 0) AS fines,
    COALESCE(s.acceptance, 0) AS acceptance,
    COALESCE(s.transit, 0) AS transit,
    COALESCE(s.disposal, 0) AS disposal,
    COALESCE(s.loss_compensation, 0) AS loss_compensation,
    COALESCE(s.freewill_compensation, 0) AS freewill_compensation,
    COALESCE(s.cost_price, 0) AS cost_price,
    COALESCE(s.seller_tax, 0) AS seller_tax,
    COALESCE(s.overheads, 0) AS overheads,
    COALESCE(s.report_totals, 0) AS report_totals,
    COALESCE(s.created_at, h.created_at) AS created_at,
    COALESCE(s.updated_at, h.updated_at) AS updated_at
FROM wb_fi_report_headers h
LEFT JOIN wb_fi_report_summary s ON h.user_id = s.user_id AND h.report_id = s.report_id
WHERE h.report_type = 1
ORDER BY h.report_id DESC;

COMMENT ON VIEW wb_fi_report_summary_view IS 
'Report summary with quantity, volume, sales_correction and for_payout';

COMMIT;

-- Rollback:
-- BEGIN;
-- DROP VIEW IF EXISTS wb_fi_report_summary_view CASCADE;
-- ALTER TABLE wb_fi_report_summary DROP COLUMN IF EXISTS for_payout;
-- DROP FUNCTION IF EXISTS update_report_totals(INTEGER, BIGINT);
-- CREATE OR REPLACE FUNCTION update_report_totals(...) ... (previous version);
-- CREATE VIEW wb_fi_report_summary_view AS ... (previous version);
-- COMMIT;