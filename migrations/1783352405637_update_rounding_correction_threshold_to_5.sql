-- ============================================================================
-- Migration: update_rounding_correction_threshold_to_5
-- Description: Change rounding correction threshold from 1 to 5 rubles
-- ============================================================================

BEGIN;

-- ============================================================================
-- 1. Обновить calculate_product_overheads
-- ============================================================================

DROP FUNCTION IF EXISTS calculate_product_overheads(INTEGER, BIGINT);

CREATE OR REPLACE FUNCTION calculate_product_overheads(
    p_user_id INTEGER,
    p_report_id BIGINT
)
RETURNS VOID LANGUAGE plpgsql AS $$
DECLARE
    v_total_volume NUMERIC(15,2);
    v_total_overheads NUMERIC(15,2);
    v_product RECORD;
    v_share NUMERIC(15,4);
    v_product_sum NUMERIC(15,2) := 0;
    v_diff NUMERIC(15,2);
    v_max_volume_nm_id BIGINT;
    v_max_volume NUMERIC(15,2) := 0;
BEGIN
    -- Получить общий объём по отчёту
    SELECT COALESCE(volume, 0) INTO v_total_volume
    FROM wb_fi_report_summary
    WHERE user_id = p_user_id AND report_id = p_report_id;
    
    -- Если общий объём = 0, ничего не делаем
    IF v_total_volume = 0 THEN
        RETURN;
    END IF;
    
    -- Получить общие overheads по отчёту
    SELECT COALESCE(overheads, 0) INTO v_total_overheads
    FROM wb_fi_report_summary
    WHERE user_id = p_user_id AND report_id = p_report_id;
    
    -- Если overheads = 0, обнуляем все товары
    IF v_total_overheads = 0 THEN
        UPDATE wb_fi_report_product_summary
        SET overheads = 0
        WHERE user_id = p_user_id AND report_id = p_report_id;
        RETURN;
    END IF;
    
    -- Найти товар с максимальным объёмом
    SELECT nm_id, COALESCE(volume, 0) INTO v_max_volume_nm_id, v_max_volume
    FROM wb_fi_report_product_summary
    WHERE user_id = p_user_id AND report_id = p_report_id
      AND (quantity != 0 OR volume != 0 OR cost_price != 0)
    ORDER BY volume DESC
    LIMIT 1;
    
    -- Рассчитать overheads для каждого товара пропорционально объёму
    FOR v_product IN
        SELECT 
            nm_id,
            COALESCE(volume, 0) AS product_volume
        FROM wb_fi_report_product_summary
        WHERE user_id = p_user_id AND report_id = p_report_id
          AND (quantity != 0 OR volume != 0 OR cost_price != 0)
    LOOP
        -- Рассчитать долю товара в общем объёме
        v_share := v_product.product_volume / v_total_volume;
        
        -- Рассчитать overheads для товара с округлением до 2 знаков
        v_product_sum := v_product_sum + ROUND(v_total_overheads * v_share, 2);
        
        -- Обновить overheads для товара
        UPDATE wb_fi_report_product_summary
        SET overheads = ROUND(v_total_overheads * v_share, 2)
        WHERE user_id = p_user_id 
          AND report_id = p_report_id 
          AND nm_id = v_product.nm_id;
    END LOOP;
    
    -- Проверить разницу между суммой overheads по товарам и общим overheads
    v_diff := v_total_overheads - v_product_sum;
    
    -- Если разница есть (по модулю меньше 5 рублей), добавить её к товару с максимальным объёмом
    IF ABS(v_diff) > 0 AND ABS(v_diff) < 5 AND v_max_volume_nm_id IS NOT NULL THEN
        UPDATE wb_fi_report_product_summary
        SET overheads = overheads + v_diff
        WHERE user_id = p_user_id 
          AND report_id = p_report_id 
          AND nm_id = v_max_volume_nm_id;
    END IF;
END;
$$;

-- ============================================================================
-- 2. Обновить calculate_product_storage
-- ============================================================================

DROP FUNCTION IF EXISTS calculate_product_storage(INTEGER, BIGINT);

CREATE OR REPLACE FUNCTION calculate_product_storage(
    p_user_id INTEGER,
    p_report_id BIGINT
)
RETURNS VOID LANGUAGE plpgsql AS $$
DECLARE
    v_total_volume NUMERIC(15,2);
    v_total_storage NUMERIC(15,2);
    v_product RECORD;
    v_share NUMERIC(15,4);
    v_product_sum NUMERIC(15,2) := 0;
    v_diff NUMERIC(15,2);
    v_max_volume_nm_id BIGINT;
    v_max_volume NUMERIC(15,2) := 0;
BEGIN
    -- Получить общий объём по отчёту
    SELECT COALESCE(volume, 0) INTO v_total_volume
    FROM wb_fi_report_summary
    WHERE user_id = p_user_id AND report_id = p_report_id;
    
    -- Если общий объём = 0, ничего не делаем
    IF v_total_volume = 0 THEN
        RETURN;
    END IF;
    
    -- Получить общие storage по отчёту
    SELECT COALESCE(storage, 0) INTO v_total_storage
    FROM wb_fi_report_summary
    WHERE user_id = p_user_id AND report_id = p_report_id;
    
    -- Если storage = 0, обнуляем все товары
    IF v_total_storage = 0 THEN
        UPDATE wb_fi_report_product_summary
        SET storage = 0
        WHERE user_id = p_user_id AND report_id = p_report_id;
        RETURN;
    END IF;
    
    -- Найти товар с максимальным объёмом
    SELECT nm_id, COALESCE(volume, 0) INTO v_max_volume_nm_id, v_max_volume
    FROM wb_fi_report_product_summary
    WHERE user_id = p_user_id AND report_id = p_report_id
      AND (quantity != 0 OR volume != 0 OR cost_price != 0)
    ORDER BY volume DESC
    LIMIT 1;
    
    -- Рассчитать storage для каждого товара пропорционально объёму
    FOR v_product IN
        SELECT 
            nm_id,
            COALESCE(volume, 0) AS product_volume
        FROM wb_fi_report_product_summary
        WHERE user_id = p_user_id AND report_id = p_report_id
          AND (quantity != 0 OR volume != 0 OR cost_price != 0)
    LOOP
        -- Рассчитать долю товара в общем объёме
        v_share := v_product.product_volume / v_total_volume;
        
        -- Рассчитать storage для товара с округлением до 2 знаков
        v_product_sum := v_product_sum + ROUND(v_total_storage * v_share, 2);
        
        -- Обновить storage для товара
        UPDATE wb_fi_report_product_summary
        SET storage = ROUND(v_total_storage * v_share, 2)
        WHERE user_id = p_user_id 
          AND report_id = p_report_id 
          AND nm_id = v_product.nm_id;
    END LOOP;
    
    -- Проверить разницу между суммой storage по товарам и общим storage
    v_diff := v_total_storage - v_product_sum;
    
    -- Если разница есть (по модулю меньше 5 рублей), добавить её к товару с максимальным объёмом
    IF ABS(v_diff) > 0 AND ABS(v_diff) < 5 AND v_max_volume_nm_id IS NOT NULL THEN
        UPDATE wb_fi_report_product_summary
        SET storage = storage + v_diff
        WHERE user_id = p_user_id 
          AND report_id = p_report_id 
          AND nm_id = v_max_volume_nm_id;
    END IF;
END;
$$;

-- ============================================================================
-- 3. Обновить distribute_advertising_to_products
-- ============================================================================

DROP FUNCTION IF EXISTS distribute_advertising_to_products(INTEGER, BIGINT, BIGINT[]);

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
    v_share NUMERIC(15,6);
    v_amount_per_product NUMERIC(15,2);
    v_campaign_products_count INTEGER;
    v_error_message TEXT;
    v_sum_distributed NUMERIC(15,2);
    v_diff NUMERIC(15,2);
    v_max_quantity_nm_id BIGINT;
    v_max_quantity NUMERIC(15,3);
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
        SELECT COUNT(*) INTO v_campaign_products_count
        FROM crm_campaign_subcards 
        WHERE advert_id = v_advert.advert_id;
        
        -- If no products in campaign, raise error
        IF v_campaign_products_count = 0 THEN
            v_error_message := FORMAT(
                'Campaign %s has no products in crm_campaign_subcards. Cannot distribute advertising costs.',
                v_advert.advert_id
            );
            RAISE EXCEPTION '%', v_error_message;
        END IF;
        
        -- Get products with sales for this advert_id (via vendorcode -> goods -> nm_id)
        SELECT 
            COALESCE(SUM(ps.quantity), 0) INTO v_total_quantity
        FROM crm_campaign_subcards cs
        JOIN goods g ON g.vendorcode = cs.vendorcode
        JOIN wb_fi_report_product_summary ps ON ps.nm_id = g.nm_id
        WHERE cs.advert_id = v_advert.advert_id
          AND ps.user_id = p_user_id 
          AND ps.report_id = p_report_id
          AND ps.quantity > 0;
        
        -- Reset sum for this campaign
        v_sum_distributed := 0;
        v_max_quantity := 0;
        v_max_quantity_nm_id := NULL;
        
        -- If there are products with sales, distribute proportionally by quantity
        IF v_total_quantity > 0 THEN
            -- First pass: calculate and store amounts, track max quantity
            FOR v_product IN
                SELECT 
                    g.nm_id,
                    ps.quantity
                FROM crm_campaign_subcards cs
                JOIN goods g ON g.vendorcode = cs.vendorcode
                JOIN wb_fi_report_product_summary ps ON ps.nm_id = g.nm_id
                WHERE cs.advert_id = v_advert.advert_id
                  AND ps.user_id = p_user_id 
                  AND ps.report_id = p_report_id
                  AND ps.quantity > 0
            LOOP
                -- Track product with max quantity
                IF v_product.quantity > v_max_quantity THEN
                    v_max_quantity := v_product.quantity;
                    v_max_quantity_nm_id := v_product.nm_id;
                END IF;
                
                v_share := v_product.quantity / v_total_quantity;
                v_amount_per_product := ROUND(v_advert.total_amount * v_share, 2);
                v_sum_distributed := v_sum_distributed + v_amount_per_product;
                
                UPDATE wb_fi_report_product_summary
                SET advertising = COALESCE(advertising, 0) + v_amount_per_product
                WHERE user_id = p_user_id 
                  AND report_id = p_report_id 
                  AND nm_id = v_product.nm_id;
            END LOOP;
            
        -- If no products with sales but campaign has products, distribute equally
        ELSIF v_campaign_products_count > 0 THEN
            -- First pass: calculate and store amounts
            FOR v_product IN
                SELECT 
                    g.nm_id
                FROM crm_campaign_subcards cs
                JOIN goods g ON g.vendorcode = cs.vendorcode
                WHERE cs.advert_id = v_advert.advert_id
            LOOP
                -- Track product (all have equal quantity in this case)
                IF v_max_quantity_nm_id IS NULL THEN
                    v_max_quantity_nm_id := v_product.nm_id;
                END IF;
                
                v_amount_per_product := ROUND(v_advert.total_amount / v_campaign_products_count, 2);
                v_sum_distributed := v_sum_distributed + v_amount_per_product;
                
                UPDATE wb_fi_report_product_summary
                SET advertising = COALESCE(advertising, 0) + v_amount_per_product
                WHERE user_id = p_user_id 
                  AND report_id = p_report_id 
                  AND nm_id = v_product.nm_id;
            END LOOP;
        END IF;
        
        -- Apply rounding correction if needed
        v_diff := v_advert.total_amount - v_sum_distributed;
        
        -- If diff exists and is less than 5 rubles, add it to the product with max quantity
        IF ABS(v_diff) > 0 AND ABS(v_diff) < 5 AND v_max_quantity_nm_id IS NOT NULL THEN
            UPDATE wb_fi_report_product_summary
            SET advertising = advertising + v_diff
            WHERE user_id = p_user_id 
              AND report_id = p_report_id 
              AND nm_id = v_max_quantity_nm_id;
        END IF;
    END LOOP;
    
    -- НЕ перезаписываем summary advertising!
END;
$$;

COMMIT;