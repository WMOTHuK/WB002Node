-- ============================================================================
-- Migration: add_advertising_distribution_to_products
-- Description: Distribute advertising costs to products based on campaign subcards and quantity
-- ============================================================================

BEGIN;

-- ============================================================================
-- 1. Функция для сбора рекламных расходов по отчёту
-- ============================================================================

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
            -- Extract upd_num from bonus_type_name (номер документа)
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
    WHERE c.user_id = p_user_id
      AND c.upd_time >= v_date_from
      AND c.upd_time < (v_date_to + INTERVAL '1 day')
    GROUP BY c.advert_id
    HAVING SUM(c.upd_sum::NUMERIC) > 0;
END;
$$;

-- ============================================================================
-- 2. Функция для распределения рекламных расходов по товарам
-- ============================================================================

CREATE OR REPLACE FUNCTION distribute_advertising_to_products(
    p_user_id INTEGER,
    p_report_id BIGINT,
    p_report_ids BIGINT[]
)
RETURNS VOID LANGUAGE plpgsql AS $$
DECLARE
    v_advert RECORD;
    v_product RECORD;
    v_total_quantity NUMERIC(15,3);
    v_products_with_sales INTEGER;
    v_share NUMERIC(15,6);
    v_amount_per_product NUMERIC(15,2);
BEGIN
    -- Clear existing advertising in product summary
    UPDATE wb_fi_report_product_summary
    SET advertising = 0
    WHERE user_id = p_user_id AND report_id = p_report_id;
    
    -- Loop through each advert_id with expenses
    FOR v_advert IN 
        SELECT advert_id, total_amount
        FROM get_advertising_expenses(p_user_id, p_report_ids)
    LOOP
        -- Check if advert has products in campaign_subcards
        IF NOT EXISTS (
            SELECT 1 FROM crm_campaign_subcards 
            WHERE advert_id = v_advert.advert_id
        ) THEN
            CONTINUE;
        END IF;
        
        -- Get products with sales for this advert_id
        -- Find products that are in this campaign AND have sales in the report
        SELECT 
            COALESCE(SUM(ps.quantity), 0) INTO v_total_quantity
        FROM crm_campaign_subcards cs
        JOIN wb_fi_report_product_summary ps ON ps.nm_id = cs.nm_id
        WHERE cs.advert_id = v_advert.advert_id
          AND ps.user_id = p_user_id 
          AND ps.report_id = p_report_id
          AND ps.quantity > 0;
        
        -- Get count of products with sales
        SELECT COUNT(*) INTO v_products_with_sales
        FROM crm_campaign_subcards cs
        JOIN wb_fi_report_product_summary ps ON ps.nm_id = cs.nm_id
        WHERE cs.advert_id = v_advert.advert_id
          AND ps.user_id = p_user_id 
          AND ps.report_id = p_report_id
          AND ps.quantity > 0;
        
        -- If there are products with sales, distribute proportionally by quantity
        IF v_total_quantity > 0 THEN
            -- Distribute by quantity
            FOR v_product IN
                SELECT 
                    ps.nm_id,
                    ps.quantity
                FROM crm_campaign_subcards cs
                JOIN wb_fi_report_product_summary ps ON ps.nm_id = cs.nm_id
                WHERE cs.advert_id = v_advert.advert_id
                  AND ps.user_id = p_user_id 
                  AND ps.report_id = p_report_id
                  AND ps.quantity > 0
            LOOP
                v_share := v_product.quantity / v_total_quantity;
                v_amount_per_product := ROUND(v_advert.total_amount * v_share, 2);
                
                UPDATE wb_fi_report_product_summary
                SET advertising = COALESCE(advertising, 0) + v_amount_per_product
                WHERE user_id = p_user_id 
                  AND report_id = p_report_id 
                  AND nm_id = v_product.nm_id;
            END LOOP;
            
        -- If no products with sales, distribute equally among all products in campaign
        ELSIF v_products_with_sales = 0 THEN
            -- Distribute equally among all products in campaign
            v_amount_per_product := ROUND(v_advert.total_amount / v_products_with_sales, 2);
            
            FOR v_product IN
                SELECT 
                    cs.nm_id
                FROM crm_campaign_subcards cs
                WHERE cs.advert_id = v_advert.advert_id
            LOOP
                UPDATE wb_fi_report_product_summary
                SET advertising = COALESCE(advertising, 0) + v_amount_per_product
                WHERE user_id = p_user_id 
                  AND report_id = p_report_id 
                  AND nm_id = v_product.nm_id;
            END LOOP;
        END IF;
    END LOOP;
    
    -- Update summary advertising as sum of product advertising
    UPDATE wb_fi_report_summary
    SET advertising = COALESCE(
        (SELECT SUM(advertising) 
         FROM wb_fi_report_product_summary 
         WHERE user_id = p_user_id AND report_id = p_report_id),
        0
    )
    WHERE user_id = p_user_id AND report_id = p_report_id;
END;
$$;

-- ============================================================================
-- 3. Обновить process_wb_report_details - добавить шаг распределения рекламы
-- ============================================================================

DROP FUNCTION IF EXISTS process_wb_report_details(INTEGER, BIGINT);

CREATE OR REPLACE FUNCTION process_wb_report_details(
    p_user_id INTEGER,
    p_report_id BIGINT
)
RETURNS TABLE (
    processed_count INTEGER,
    summary_updated BOOLEAN,
    unmatched_count INTEGER,
    unmatched_sample JSONB
) LANGUAGE plpgsql AS $$
DECLARE
    v_report_ids BIGINT[];
    v_combined_report_id BIGINT;
    v_processed_count INTEGER := 0;
    v_unmatched_count INTEGER := 0;
    v_unmatched_sample JSONB := '[]'::JSONB;
    v_metrics JSONB;
    v_qv RECORD;
    v_total_quantity NUMERIC(15,3) := 0;
    v_total_volume NUMERIC(15,2) := 0;
    v_total_cost_price NUMERIC(15,2) := 0;
    v_report_totals NUMERIC(15,2) := 0;
BEGIN
    -- 1. Get combined report_ids
    v_report_ids := get_combined_report_ids(p_user_id, p_report_id);
    v_combined_report_id := v_report_ids[1];
    
    -- 2. Clear existing summary
    DELETE FROM wb_fi_report_summary 
    WHERE user_id = p_user_id AND report_id = v_combined_report_id;
    
    -- 3. Clear existing product summary
    DELETE FROM wb_fi_report_product_summary 
    WHERE user_id = p_user_id AND report_id = v_combined_report_id;
    
    -- 4. Calculate basic metrics
    v_metrics := calculate_wb_basic_metrics(p_user_id, v_report_ids);
    
    -- 5. Insert summary (without quantity and volume yet)
    PERFORM insert_wb_basic_metrics(p_user_id, v_combined_report_id, v_metrics);
    
    -- 6. Create product records
    PERFORM create_product_records(p_user_id, v_combined_report_id, v_report_ids);
    
    -- 7. Update product fields (revenue, for_pay, logistics, etc.)
    PERFORM update_product_fields(p_user_id, v_combined_report_id, v_report_ids);
    
    -- 8. Calculate quantity, volume and cost_price
    PERFORM update_product_quantity_volume_cost(p_user_id, v_combined_report_id, v_report_ids);
    
    -- 9. Update summary with quantity, volume, cost_price
    PERFORM update_summary_quantity_volume_cost(p_user_id, v_combined_report_id, v_report_ids);
    
    -- 10. Update complex fields (seller_tax, overheads, logistics_total)
    PERFORM update_wb_complex_fields(p_user_id, v_report_ids, v_combined_report_id);
    
    -- 11. Distribute advertising costs to products (NEW STEP)
    PERFORM distribute_advertising_to_products(p_user_id, v_combined_report_id, v_report_ids);
    
    -- 12. Update report_totals (LAST STEP)
    PERFORM update_report_totals(p_user_id, v_combined_report_id);
    
    -- 13. Get processed count
    SELECT COUNT(*) INTO v_processed_count
    FROM wb_fi_report_details
    WHERE user_id = p_user_id 
      AND report_id = ANY(v_report_ids);
    
    -- 14. Find unmatched rows
    v_unmatched_count := find_wb_unmatched_rows(p_user_id, v_combined_report_id);
    
    -- 15. Get unmatched sample
    IF v_unmatched_count > 0 THEN
        SELECT get_wb_unmatched_sample(p_user_id, v_combined_report_id, 10) INTO v_unmatched_sample;
    END IF;
    
    -- 16. Return results
    RETURN QUERY SELECT 
        v_processed_count,
        TRUE,
        v_unmatched_count,
        COALESCE(v_unmatched_sample, '[]'::JSONB);
END;
$$;

COMMENT ON FUNCTION process_wb_report_details(INTEGER, BIGINT) IS 
'Process Wildberries financial report details with advertising distribution.';

COMMIT;