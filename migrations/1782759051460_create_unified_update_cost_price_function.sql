-- ============================================================================
-- Migration: create_unified_update_cost_price_function
-- Description: Unified function to update cost price for any platform
-- ============================================================================

BEGIN;

DROP FUNCTION IF EXISTS update_cost_price(VARCHAR(10), VARCHAR(10), NUMERIC, DATE);
DROP FUNCTION IF EXISTS update_wb_cost_price(VARCHAR(10), NUMERIC, DATE);
DROP FUNCTION IF EXISTS update_ozon_cost_price(VARCHAR(10), NUMERIC, DATE);

CREATE OR REPLACE FUNCTION update_cost_price(
    p_vendorcode VARCHAR(10),
    p_platform_code VARCHAR(10),
    p_new_cost NUMERIC(12,2),
    p_start_date DATE
)
RETURNS TABLE(
    status TEXT,
    message TEXT,
    platform_code VARCHAR(10),
    platform_name VARCHAR(50),
    old_cost NUMERIC(12,2),
    new_cost NUMERIC(12,2),
    effective_from DATE,
    effective_to DATE
) AS $$
DECLARE
    v_current_cost NUMERIC(12,2);
    v_current_beg_date DATE;
    v_previous_end_date DATE;
    v_field_name TEXT;
    v_platform_name VARCHAR(50);
    v_platform_exists BOOLEAN;
BEGIN
    -- Проверяем существование товара
    IF NOT EXISTS (SELECT 1 FROM public.goods WHERE vendorcode = p_vendorcode) THEN
        RETURN QUERY SELECT 
            'ERROR'::TEXT, 
            'Товар с vendorcode ' || p_vendorcode || ' не найден'::TEXT,
            NULL::VARCHAR(10), NULL::VARCHAR(50), NULL::NUMERIC, NULL::NUMERIC, NULL::DATE, NULL::DATE;
        RETURN;
    END IF;
    
    -- Проверяем существование платформы и получаем её название
    SELECT name INTO v_platform_name
    FROM public.gen_platforms
    WHERE code = p_platform_code AND active = TRUE;
    
    IF v_platform_name IS NULL THEN
        RETURN QUERY SELECT 
            'ERROR'::TEXT, 
            'Неизвестная платформа: ' || p_platform_code || '. Проверьте таблицу gen_platforms'::TEXT,
            NULL::VARCHAR(10), NULL::VARCHAR(50), NULL::NUMERIC, NULL::NUMERIC, NULL::DATE, NULL::DATE;
        RETURN;
    END IF;
    
    -- Определяем поле для обновления в зависимости от платформы
    v_field_name := CASE p_platform_code
        WHEN 'wb' THEN 'wb_cost_value'
        WHEN 'ozon' THEN 'ozon_cost_value'
        ELSE NULL
    END;
    
    -- Если поле не определено, создаём новое поле динамически (для будущих платформ)
    IF v_field_name IS NULL THEN
        -- Проверяем, существует ли колонка для этой платформы
        PERFORM 1 
        FROM information_schema.columns 
        WHERE table_name = 'cost_price' 
          AND column_name = p_platform_code || '_cost_value';
        
        IF NOT FOUND THEN
            -- Создаём новую колонку для платформы
            EXECUTE FORMAT(
                'ALTER TABLE cost_price ADD COLUMN %I NUMERIC(12,2)',
                p_platform_code || '_cost_value'
            );
            
            -- Добавляем комментарий
            EXECUTE FORMAT(
                'COMMENT ON COLUMN cost_price.%I IS ''Cost price for ' || v_platform_name || '''',
                p_platform_code || '_cost_value'
            );
        END IF;
        
        v_field_name := p_platform_code || '_cost_value';
    END IF;
    
    -- Проверяем, что новая дата не раньше текущей
    IF p_start_date <= CURRENT_DATE THEN
        RETURN QUERY SELECT 
            'ERROR'::TEXT, 
            'Дата начала должна быть больше текущей даты'::TEXT,
            p_platform_code, v_platform_name, NULL::NUMERIC, NULL::NUMERIC, NULL::DATE, NULL::DATE;
        RETURN;
    END IF;
    
    -- Находим текущую активную себестоимость для указанной платформы
    EXECUTE FORMAT(
        'SELECT %I, beg_date FROM public.cost_price
         WHERE vendorcode = $1 AND end_date IS NULL
         FOR UPDATE',
        v_field_name
    ) INTO v_current_cost, v_current_beg_date USING p_vendorcode;
    
    -- Если текущей себестоимости нет, создаем первую запись
    IF v_current_cost IS NULL THEN
        EXECUTE FORMAT(
            'INSERT INTO public.cost_price (vendorcode, %I, beg_date, end_date)
             VALUES ($1, $2, $3, NULL)',
            v_field_name
        ) USING p_vendorcode, p_new_cost, p_start_date;
        
        RETURN QUERY SELECT 
            'SUCCESS'::TEXT, 
            'Создана новая себестоимость для ' || v_platform_name || ' (активная запись отсутствовала)'::TEXT,
            p_platform_code, v_platform_name, NULL::NUMERIC, p_new_cost, p_start_date, NULL::DATE;
        RETURN;
    END IF;
    
    -- Проверяем, не пытаемся ли установить ту же себестоимость
    IF v_current_cost = p_new_cost THEN
        RETURN QUERY SELECT 
            'WARNING'::TEXT, 
            'Себестоимость для ' || v_platform_name || ' не изменилась, обновление не требуется'::TEXT,
            p_platform_code, v_platform_name, v_current_cost, p_new_cost, NULL::DATE, NULL::DATE;
        RETURN;
    END IF;
    
    -- Основная логика: закрываем текущий период и создаем новый
    v_previous_end_date := p_start_date - INTERVAL '1 day';
    
    -- Обновляем текущую запись (закрываем период)
    UPDATE public.cost_price
    SET end_date = v_previous_end_date,
        updated_at = CURRENT_TIMESTAMP
    WHERE vendorcode = p_vendorcode AND end_date IS NULL;
    
    -- Создаем новую запись с новой себестоимостью для указанной платформы
    EXECUTE FORMAT(
        'INSERT INTO public.cost_price (vendorcode, %I, beg_date, end_date)
         VALUES ($1, $2, $3, NULL)',
        v_field_name
    ) USING p_vendorcode, p_new_cost, p_start_date;
    
    -- Возвращаем результат
    RETURN QUERY SELECT 
        'SUCCESS'::TEXT, 
        'Себестоимость для ' || v_platform_name || ' успешно обновлена'::TEXT,
        p_platform_code, v_platform_name, v_current_cost, p_new_cost, p_start_date, v_previous_end_date;
        
EXCEPTION
    WHEN OTHERS THEN
        RETURN QUERY SELECT 
            'ERROR'::TEXT, 
            'Ошибка: ' || SQLERRM::TEXT,
            p_platform_code, v_platform_name, NULL::NUMERIC, NULL::NUMERIC, NULL::DATE, NULL::DATE;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION update_cost_price(VARCHAR(10), VARCHAR(10), NUMERIC(12,2), DATE) IS 
'Unified function to update cost price for any platform (wb, ozon, etc.). Auto-creates new columns for new platforms.';

COMMIT;