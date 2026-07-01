-- ============================================================================
-- Migration: fix_get_advertising_expenses_user_id
-- Description: Remove user_id condition from crm_campaign_costs
-- ============================================================================

BEGIN;

DROP FUNCTION IF EXISTS get_advertising_expenses(INTEGER, BIGINT[]);

CREATE OR REPLACE FUNCTION get_advertising_expenses(
    p_user_id INTEGER,
    p_report_ids BIGINT[]
)
RETURNS TABLE (
    advert_id INTEGER,
    total_amount NUMERIC(15,2)
) LANGUAGE plpgsql STABLE AS $$
DECLARE
    v_date_from DATE;
    v_date_to DATE;
    v_report_id BIGINT;
BEGIN
    -- Get date range from report_type = 1
    SELECT h.date_from, h.date_to, h.report_id INTO v_date_from, v_date_to, v_report_id
    FROM wb_fi_report_headers h
    WHERE h.user_id = p_user_id 
      AND h.report_id = ANY(p_report_ids)
      AND h.report_type = 1
    LIMIT 1;
    
    IF v_date_from IS NULL THEN
        RETURN;
    END IF;
    
    -- Get advertising expenses from details grouped by advert_id
    RETURN QUERY
    WITH advertising_details AS (
        SELECT 
            d.bonus_type_name,
            d.deduction,
            -- Extract upd_num from bonus_type_name
            NULLIF(
                REGEXP_REPLACE(
                    d.bonus_type_name, 
                    '.*документ №(\d+).*', 
                    '\1', 
                    'g'
                ), 
                d.bonus_type_name
            ) AS upd_num_text
        FROM wb_fi_report_details d
        WHERE d.user_id = p_user_id 
          AND d.report_id = ANY(p_report_ids)
          AND d.seller_oper_name = 'Удержание'
          AND d.bonus_type_name LIKE 'Оказание услуг «WB Продвижение»%'
    ),
    upd_nums AS (
        SELECT DISTINCT upd_num_text::BIGINT AS upd_num
        FROM advertising_details
        WHERE upd_num_text IS NOT NULL
    )
    SELECT 
        c.advert_id,
        SUM(c.upd_sum::NUMERIC) AS total_amount
    FROM upd_nums u
    JOIN crm_campaign_costs c ON c.upd_num = u.upd_num
    WHERE c.upd_time >= v_date_from
      AND c.upd_time < (v_date_to + INTERVAL '1 day')
    GROUP BY c.advert_id
    HAVING SUM(c.upd_sum::NUMERIC) > 0;
END;
$$;

COMMENT ON FUNCTION get_advertising_expenses(INTEGER, BIGINT[]) IS 
'Get advertising expenses grouped by advert_id for the report period.';

COMMIT;