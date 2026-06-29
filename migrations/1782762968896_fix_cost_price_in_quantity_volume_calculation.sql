-- ============================================================================
-- Migration: fix_cost_price_in_quantity_volume_calculation
-- Description: Use only WB cost price for quantity/volume calculation
-- ============================================================================

BEGIN;

-- 1. Обновить функцию для расчёта quantity, volume и cost_price по товарам
DROP FUNCTION IF EXISTS calculate_wb_product_quantity_volume_cost(INTEGER, BIGINT[]);

CREATE OR REPLACE FUNCTION calculate_wb_product_quantity_volume_cost(
    p_user_id INTEGER,
    p_report_ids BIGINT[]
)
RETURNS TABLE (
    nm_id BIGINT,
    quantity NUMERIC(15,3),
    volume NUMERIC(15,2),
    cost_price NUMERIC(15,2)
) LANGUAGE plpgsql STABLE AS $$
DECLARE
    v_date_from DATE;
    v_report_id BIGINT;
BEGIN
    -- Get date_from from report_type = 1
    SELECT h.date_from, h.report_id INTO v_date_from, v_report_id
    FROM wb_fi_report_headers h
    WHERE h.user_id = p_user_id 
      AND h.report_id = ANY(p_report_ids)
      AND h.report_type = 1
    LIMIT 1;
    
    -- If no type 1 found, try any report
    IF v_date_from IS NULL THEN
        SELECT h.date_from, h.report_id INTO v_date_from, v_report_id
        FROM wb_fi_report_headers h
        WHERE h.user_id = p_user_id 
          AND h.report_id = ANY(p_report_ids)
        LIMIT 1;
    END IF;
    
    -- If still no date, return empty
    IF v_date_from IS NULL THEN
        RETURN;
    END IF;
    
    RETURN QUERY
    SELECT 
        d.nm_id,
        COALESCE(SUM(
            CASE 
                WHEN d.seller_oper_name = 'Продажа' THEN d.quantity::NUMERIC
                WHEN d.seller_oper_name = 'Возврат' THEN -d.quantity::NUMERIC
                ELSE 0
            END
        ), 0) AS quantity,
        COALESCE(SUM(
            CASE 
                WHEN d.seller_oper_name = 'Продажа' THEN d.quantity::NUMERIC * COALESCE(g.wbvol, 0)
                WHEN d.seller_oper_name = 'Возврат' THEN -d.quantity::NUMERIC * COALESCE(g.wbvol, 0)
                ELSE 0
            END
        ), 0) AS volume,
        COALESCE(SUM(
            CASE 
                WHEN d.seller_oper_name = 'Продажа' THEN d.quantity::NUMERIC * COALESCE(cp.cost_value, 0)
                WHEN d.seller_oper_name = 'Возврат' THEN -d.quantity::NUMERIC * COALESCE(cp.cost_value, 0)
                ELSE 0
            END
        ), 0) AS cost_price
    FROM wb_fi_report_details d
    LEFT JOIN goods g ON g.nm_id = d.nm_id
    LEFT JOIN LATERAL (
        SELECT cp.cost_value
        FROM cost_price cp
        WHERE cp.vendorcode = g.vendorcode
          AND cp.platform = 'wb'  -- ТОЛЬКО WB!
          AND cp.beg_date <= v_date_from
          AND (cp.end_date IS NULL OR cp.end_date >= v_date_from)
        ORDER BY cp.beg_date DESC
        LIMIT 1
    ) cp ON TRUE
    WHERE d.user_id = p_user_id 
      AND d.report_id = ANY(p_report_ids)
      AND d.nm_id IS NOT NULL
      AND d.nm_id != 0
      AND d.seller_oper_name IN ('Продажа', 'Возврат')
    GROUP BY d.nm_id
    ORDER BY d.nm_id;
END;
$$;

COMMENT ON FUNCTION calculate_wb_product_quantity_volume_cost(INTEGER, BIGINT[]) IS 
'Calculate quantity, volume and WB cost_price for each product.';

-- 2. Обновить функцию для общих итогов
DROP FUNCTION IF EXISTS calculate_wb_total_quantity_volume_cost(INTEGER, BIGINT[]);

CREATE OR REPLACE FUNCTION calculate_wb_total_quantity_volume_cost(
    p_user_id INTEGER,
    p_report_ids BIGINT[]
)
RETURNS TABLE (
    total_quantity NUMERIC(15,3),
    total_volume NUMERIC(15,2),
    total_cost_price NUMERIC(15,2)
) LANGUAGE sql STABLE AS $$
    SELECT 
        COALESCE(SUM(
            CASE 
                WHEN d.seller_oper_name = 'Продажа' THEN d.quantity::NUMERIC
                WHEN d.seller_oper_name = 'Возврат' THEN -d.quantity::NUMERIC
                ELSE 0
            END
        ), 0) AS total_quantity,
        COALESCE(SUM(
            CASE 
                WHEN d.seller_oper_name = 'Продажа' THEN d.quantity::NUMERIC * COALESCE(g.wbvol, 0)
                WHEN d.seller_oper_name = 'Возврат' THEN -d.quantity::NUMERIC * COALESCE(g.wbvol, 0)
                ELSE 0
            END
        ), 0) AS total_volume,
        COALESCE(SUM(
            CASE 
                WHEN d.seller_oper_name = 'Продажа' THEN d.quantity::NUMERIC * COALESCE(cp.cost_value, 0)
                WHEN d.seller_oper_name = 'Возврат' THEN -d.quantity::NUMERIC * COALESCE(cp.cost_value, 0)
                ELSE 0
            END
        ), 0) AS total_cost_price
    FROM wb_fi_report_details d
    LEFT JOIN goods g ON g.nm_id = d.nm_id
    LEFT JOIN LATERAL (
        SELECT cp.cost_value
        FROM cost_price cp
        WHERE cp.vendorcode = g.vendorcode
          AND cp.platform = 'wb'  -- ТОЛЬКО WB!
          AND cp.beg_date <= (SELECT date_from FROM wb_fi_report_headers h 
                              WHERE h.user_id = p_user_id 
                                AND h.report_id = ANY(p_report_ids)
                                AND h.report_type = 1
                              LIMIT 1)
          AND (cp.end_date IS NULL OR cp.end_date >= (SELECT date_from FROM wb_fi_report_headers h 
                                                       WHERE h.user_id = p_user_id 
                                                         AND h.report_id = ANY(p_report_ids)
                                                         AND h.report_type = 1
                                                       LIMIT 1))
        ORDER BY cp.beg_date DESC
        LIMIT 1
    ) cp ON TRUE
    WHERE d.user_id = p_user_id 
      AND d.report_id = ANY(p_report_ids)
      AND d.nm_id IS NOT NULL
      AND d.nm_id != 0
      AND d.seller_oper_name IN ('Продажа', 'Возврат');
$$;

COMMENT ON FUNCTION calculate_wb_total_quantity_volume_cost(INTEGER, BIGINT[]) IS 
'Calculate total quantity, volume and WB cost_price for all products.';

COMMIT;