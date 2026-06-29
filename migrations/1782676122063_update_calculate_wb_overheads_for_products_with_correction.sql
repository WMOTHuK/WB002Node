-- ============================================================================
-- Migration: update_calculate_wb_overheads_for_products_with_correction
-- Description: Calculate overheads for product summary with rounding correction
-- ============================================================================

BEGIN;

-- 1. Функция для расчёта overheads по товарам (пропорционально объёму с коррекцией)
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
    
    -- Если разница есть (по модулю меньше 1 рубля), добавить её к товару с максимальным объёмом
    IF ABS(v_diff) > 0 AND ABS(v_diff) < 1 AND v_max_volume_nm_id IS NOT NULL THEN
        UPDATE wb_fi_report_product_summary
        SET overheads = overheads + v_diff
        WHERE user_id = p_user_id 
          AND report_id = p_report_id 
          AND nm_id = v_max_volume_nm_id;
    END IF;
END;
$$;

-- 2. Обновить функцию update_wb_complex_fields
DROP FUNCTION IF EXISTS update_wb_complex_fields(INTEGER, BIGINT[], BIGINT);

CREATE OR REPLACE FUNCTION update_wb_complex_fields(
    p_user_id INTEGER,
    p_report_ids BIGINT[],
    p_summary_report_id BIGINT
)
RETURNS VOID LANGUAGE plpgsql AS $$
DECLARE
    v_product RECORD;
    v_seller_tax_total NUMERIC(15,2) := 0;
    v_logistics_total NUMERIC(15,2) := 0;
    v_overheads_total NUMERIC(15,2) := 0;
BEGIN
    -- 1. Update seller_tax in product summary
    FOR v_product IN 
        SELECT * FROM calculate_wb_seller_tax_by_product(p_user_id, p_report_ids)
    LOOP
        UPDATE wb_fi_report_product_summary
        SET seller_tax = v_product.seller_tax
        WHERE user_id = p_user_id 
          AND report_id = p_summary_report_id 
          AND nm_id = v_product.nm_id;
        
        v_seller_tax_total := v_seller_tax_total + v_product.seller_tax;
    END LOOP;
    
    -- 2. Update logistics_total in product summary
    FOR v_product IN 
        SELECT * FROM calculate_product_logistics_total(p_user_id, p_report_ids)
    LOOP
        UPDATE wb_fi_report_product_summary
        SET logistics_total = v_product.logistics_total
        WHERE user_id = p_user_id 
          AND report_id = p_summary_report_id 
          AND nm_id = v_product.nm_id;
    END LOOP;
    
    -- 3. Calculate total overheads for summary
    v_overheads_total := calculate_wb_overheads(p_user_id, p_report_ids);
    
    -- 4. Update summary table (seller_tax, overheads, logistics_total)
    SELECT calculate_wb_logistics_total(p_user_id, p_report_ids) INTO v_logistics_total;
    
    UPDATE wb_fi_report_summary
    SET 
        seller_tax = v_seller_tax_total,
        overheads = v_overheads_total,
        logistics_total = v_logistics_total
    WHERE user_id = p_user_id AND report_id = p_summary_report_id;
    
    -- 5. Update product overheads (proportionally by volume with correction)
    PERFORM calculate_product_overheads(p_user_id, p_summary_report_id);
END;
$$;

COMMENT ON FUNCTION update_wb_complex_fields(INTEGER, BIGINT[], BIGINT) IS 
'Update complex fields including overheads distribution to products with rounding correction';

COMMIT;