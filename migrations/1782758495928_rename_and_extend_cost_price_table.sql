-- ============================================================================
-- Migration: rename_and_extend_cost_price_table
-- Description: Rename cost_value to wb_cost_value, add ozon_cost_value, update functions
-- ============================================================================

BEGIN;

-- ============================================================================
-- 1. Переименование поля cost_value в wb_cost_value
-- ============================================================================

-- Переименовать поле в таблице
ALTER TABLE cost_price RENAME COLUMN cost_value TO wb_cost_value;

-- Добавить поле для Ozon
ALTER TABLE cost_price ADD COLUMN ozon_cost_value NUMERIC(12,2);

-- Добавить комментарии
COMMENT ON COLUMN cost_price.wb_cost_value IS 'Cost price for Wildberries';
COMMENT ON COLUMN cost_price.ozon_cost_value IS 'Cost price for Ozon';

-- ============================================================================
-- 2. Переименование функции update_cost_price в update_wb_cost_price
-- ============================================================================

DROP FUNCTION IF EXISTS update_cost_price(VARCHAR(10), NUMERIC, DATE);

CREATE OR REPLACE FUNCTION update_wb_cost_price(
    p_vendorcode VARCHAR(10),
    p_new_cost NUMERIC(12,2),
    p_start_date DATE
)
RETURNS TABLE(
    status TEXT,
    message TEXT,
    old_cost NUMERIC(12,2),
    new_cost NUMERIC(12,2),
    effective_from DATE,
    effective_to DATE
) AS $$
DECLARE
    v_current_cost NUMERIC(12,2);
    v_current_beg_date DATE;
    v_previous_end_date DATE;
BEGIN
    -- Проверяем существование товара
    IF NOT EXISTS (SELECT 1 FROM public.goods WHERE vendorcode = p_vendorcode) THEN
        RETURN QUERY SELECT 
            'ERROR'::TEXT, 
            'Товар с vendorcode ' || p_vendorcode || ' не найден'::TEXT,
            NULL::NUMERIC, NULL::NUMERIC, NULL::DATE, NULL::DATE;
        RETURN;
    END IF;
    
    -- Проверяем, что новая дата не раньше текущей
    IF p_start_date <= CURRENT_DATE THEN
        RETURN QUERY SELECT 
            'ERROR'::TEXT, 
            'Дата начала должна быть больше текущей даты'::TEXT,
            NULL::NUMERIC, NULL::NUMERIC, NULL::DATE, NULL::DATE;
        RETURN;
    END IF;
    
    -- Находим текущую активную себестоимость для WB
    SELECT wb_cost_value, beg_date INTO v_current_cost, v_current_beg_date
    FROM public.cost_price
    WHERE vendorcode = p_vendorcode AND end_date IS NULL
    FOR UPDATE;
    
    -- Если текущей себестоимости нет, создаем первую запись
    IF v_current_cost IS NULL THEN
        INSERT INTO public.cost_price (vendorcode, wb_cost_value, beg_date, end_date)
        VALUES (p_vendorcode, p_new_cost, p_start_date, NULL);
        
        RETURN QUERY SELECT 
            'SUCCESS'::TEXT, 
            'Создана новая себестоимость WB (активная запись отсутствовала)'::TEXT,
            NULL::NUMERIC, p_new_cost, p_start_date, NULL::DATE;
        RETURN;
    END IF;
    
    -- Проверяем, не пытаемся ли установить ту же себестоимость
    IF v_current_cost = p_new_cost THEN
        RETURN QUERY SELECT 
            'WARNING'::TEXT, 
            'Себестоимость WB не изменилась, обновление не требуется'::TEXT,
            v_current_cost, p_new_cost, NULL::DATE, NULL::DATE;
        RETURN;
    END IF;
    
    -- Основная логика: закрываем текущий период и создаем новый
    v_previous_end_date := p_start_date - INTERVAL '1 day';
    
    -- Обновляем текущую запись (закрываем период)
    UPDATE public.cost_price
    SET end_date = v_previous_end_date,
        updated_at = CURRENT_TIMESTAMP
    WHERE vendorcode = p_vendorcode AND end_date IS NULL;
    
    -- Создаем новую запись с новой себестоимостью для WB
    INSERT INTO public.cost_price (vendorcode, wb_cost_value, beg_date, end_date)
    VALUES (p_vendorcode, p_new_cost, p_start_date, NULL);
    
    -- Возвращаем результат
    RETURN QUERY SELECT 
        'SUCCESS'::TEXT, 
        'Себестоимость WB успешно обновлена'::TEXT,
        v_current_cost, p_new_cost, p_start_date, v_previous_end_date;
        
EXCEPTION
    WHEN OTHERS THEN
        RETURN QUERY SELECT 
            'ERROR'::TEXT, 
            'Ошибка: ' || SQLERRM::TEXT,
            NULL::NUMERIC, NULL::NUMERIC, NULL::DATE, NULL::DATE;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 3. Функция для обновления себестоимости Ozon
-- ============================================================================

CREATE OR REPLACE FUNCTION update_ozon_cost_price(
    p_vendorcode VARCHAR(10),
    p_new_cost NUMERIC(12,2),
    p_start_date DATE
)
RETURNS TABLE(
    status TEXT,
    message TEXT,
    old_cost NUMERIC(12,2),
    new_cost NUMERIC(12,2),
    effective_from DATE,
    effective_to DATE
) AS $$
DECLARE
    v_current_cost NUMERIC(12,2);
    v_current_beg_date DATE;
    v_previous_end_date DATE;
BEGIN
    -- Проверяем существование товара
    IF NOT EXISTS (SELECT 1 FROM public.goods WHERE vendorcode = p_vendorcode) THEN
        RETURN QUERY SELECT 
            'ERROR'::TEXT, 
            'Товар с vendorcode ' || p_vendorcode || ' не найден'::TEXT,
            NULL::NUMERIC, NULL::NUMERIC, NULL::DATE, NULL::DATE;
        RETURN;
    END IF;
    
    -- Проверяем, что новая дата не раньше текущей
    IF p_start_date <= CURRENT_DATE THEN
        RETURN QUERY SELECT 
            'ERROR'::TEXT, 
            'Дата начала должна быть больше текущей даты'::TEXT,
            NULL::NUMERIC, NULL::NUMERIC, NULL::DATE, NULL::DATE;
        RETURN;
    END IF;
    
    -- Находим текущую активную себестоимость для Ozon
    SELECT ozon_cost_value, beg_date INTO v_current_cost, v_current_beg_date
    FROM public.cost_price
    WHERE vendorcode = p_vendorcode AND end_date IS NULL
    FOR UPDATE;
    
    -- Если текущей себестоимости нет, создаем первую запись
    IF v_current_cost IS NULL THEN
        INSERT INTO public.cost_price (vendorcode, ozon_cost_value, beg_date, end_date)
        VALUES (p_vendorcode, p_new_cost, p_start_date, NULL);
        
        RETURN QUERY SELECT 
            'SUCCESS'::TEXT, 
            'Создана новая себестоимость Ozon (активная запись отсутствовала)'::TEXT,
            NULL::NUMERIC, p_new_cost, p_start_date, NULL::DATE;
        RETURN;
    END IF;
    
    -- Проверяем, не пытаемся ли установить ту же себестоимость
    IF v_current_cost = p_new_cost THEN
        RETURN QUERY SELECT 
            'WARNING'::TEXT, 
            'Себестоимость Ozon не изменилась, обновление не требуется'::TEXT,
            v_current_cost, p_new_cost, NULL::DATE, NULL::DATE;
        RETURN;
    END IF;
    
    -- Основная логика: закрываем текущий период и создаем новый
    v_previous_end_date := p_start_date - INTERVAL '1 day';
    
    -- Обновляем текущую запись (закрываем период)
    UPDATE public.cost_price
    SET end_date = v_previous_end_date,
        updated_at = CURRENT_TIMESTAMP
    WHERE vendorcode = p_vendorcode AND end_date IS NULL;
    
    -- Создаем новую запись с новой себестоимостью для Ozon
    INSERT INTO public.cost_price (vendorcode, ozon_cost_value, beg_date, end_date)
    VALUES (p_vendorcode, p_new_cost, p_start_date, NULL);
    
    -- Возвращаем результат
    RETURN QUERY SELECT 
        'SUCCESS'::TEXT, 
        'Себестоимость Ozon успешно обновлена'::TEXT,
        v_current_cost, p_new_cost, p_start_date, v_previous_end_date;
        
EXCEPTION
    WHEN OTHERS THEN
        RETURN QUERY SELECT 
            'ERROR'::TEXT, 
            'Ошибка: ' || SQLERRM::TEXT,
            NULL::NUMERIC, NULL::NUMERIC, NULL::DATE, NULL::DATE;
END;
$$ LANGUAGE plpgsql;

-- ============================================================================
-- 4. Обновление product_data view
-- ============================================================================

DROP VIEW IF EXISTS product_data CASCADE;

CREATE VIEW product_data AS
SELECT 
    g.card_photo,
    g.title,
    g.vendorcode,
    g.nm_id,
    g.wbvol,
    g.ozid,
    g.ozvol,
    g.imtid,
    cp.wb_cost_value AS current_cost,
    '2026-01-01'::DATE AS change_date,
    g.deleted,
    COALESCE(gt.name_ru, '') AS goods_type_name,
    g.goods_grp_id,
    COALESCE(gg.name_ru, '') AS goods_grp_name
FROM goods g
LEFT JOIN cost_price cp ON cp.vendorcode = g.vendorcode AND cp.end_date IS NULL
LEFT JOIN goods_grp_active_multilang gg ON g.goods_grp_id = gg.id
LEFT JOIN goods_type_active_multilang gt ON gg.goods_type_id = gt.id
ORDER BY g.vendorcode;

-- ============================================================================
-- 5. Обновление комментариев
-- ============================================================================

COMMENT ON FUNCTION update_wb_cost_price(VARCHAR(10), NUMERIC(12,2), DATE) IS 
'Update Wildberries cost price for a product. Closes old period and creates new one.';

COMMENT ON FUNCTION update_ozon_cost_price(VARCHAR(10), NUMERIC(12,2), DATE) IS 
'Update Ozon cost price for a product. Closes old period and creates new one.';

COMMIT;

-- Rollback:
-- BEGIN;
-- DROP VIEW IF EXISTS product_data CASCADE;
-- DROP FUNCTION IF EXISTS update_ozon_cost_price(VARCHAR(10), NUMERIC(12,2), DATE);
-- DROP FUNCTION IF EXISTS update_wb_cost_price(VARCHAR(10), NUMERIC(12,2), DATE);
-- ALTER TABLE cost_price DROP COLUMN IF EXISTS ozon_cost_value;
-- ALTER TABLE cost_price RENAME COLUMN wb_cost_value TO cost_value;
-- CREATE OR REPLACE VIEW product_data AS ... (previous version);
-- CREATE OR REPLACE FUNCTION update_cost_price(...) ... (previous version);
-- COMMIT;