-- ============================================================================
-- Migration: fix_update_cost_price_ambiguous_platform
-- Description: Fix ambiguous platform reference
-- ============================================================================

BEGIN;

DROP FUNCTION IF EXISTS update_cost_price(VARCHAR(10), VARCHAR(10), NUMERIC, DATE);

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
    v_platform_name VARCHAR(50);
BEGIN
    -- Проверяем существование товара
    IF NOT EXISTS (SELECT 1 FROM public.goods WHERE vendorcode = p_vendorcode) THEN
        RETURN QUERY SELECT 
            'ERROR'::TEXT, 
            'Товар с vendorcode ' || p_vendorcode || ' не найден'::TEXT,
            NULL::VARCHAR(10), NULL::VARCHAR(50), NULL::NUMERIC, NULL::NUMERIC, NULL::DATE, NULL::DATE;
        RETURN;
    END IF;
    
    -- Проверяем существование платформы
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
    
    -- Находим текущую активную себестоимость для указанной платформы
    SELECT cp.cost_value, cp.beg_date INTO v_current_cost, v_current_beg_date
    FROM public.cost_price cp
    WHERE cp.vendorcode = p_vendorcode 
      AND cp.platform = p_platform_code
      AND cp.end_date IS NULL
    FOR UPDATE;
    
    -- Если текущей себестоимости нет, создаем первую запись (можно с любой датой)
    IF v_current_cost IS NULL THEN
        INSERT INTO public.cost_price (vendorcode, platform, cost_value, beg_date, end_date)
        VALUES (p_vendorcode, p_platform_code, p_new_cost, p_start_date, NULL);
        
        RETURN QUERY SELECT 
            'SUCCESS'::TEXT, 
            'Создана новая себестоимость для ' || v_platform_name || ' (активная запись отсутствовала)'::TEXT,
            p_platform_code, v_platform_name, NULL::NUMERIC, p_new_cost, p_start_date, NULL::DATE;
        RETURN;
    END IF;
    
    -- Проверяем, что новая дата не раньше даты начала текущей активной себестоимости
    IF p_start_date <= v_current_beg_date THEN
        RETURN QUERY SELECT 
            'ERROR'::TEXT, 
            'Дата начала (' || p_start_date || ') должна быть больше даты начала текущей себестоимости (' || v_current_beg_date || ')'::TEXT,
            p_platform_code, v_platform_name, v_current_cost, p_new_cost, NULL::DATE, NULL::DATE;
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
    
    -- Проверяем, что новая дата не конфликтует с существующими периодами
    IF EXISTS (
        SELECT 1 FROM public.cost_price cp
        WHERE cp.vendorcode = p_vendorcode 
          AND cp.platform = p_platform_code
          AND cp.beg_date < p_start_date
          AND cp.end_date >= p_start_date
    ) THEN
        RETURN QUERY SELECT 
            'ERROR'::TEXT, 
            'Дата начала (' || p_start_date || ') конфликтует с существующим периодом'::TEXT,
            p_platform_code, v_platform_name, v_current_cost, p_new_cost, NULL::DATE, NULL::DATE;
        RETURN;
    END IF;
    
    -- Обновляем текущую запись (закрываем период)
    UPDATE public.cost_price
    SET end_date = v_previous_end_date,
        updated_at = CURRENT_TIMESTAMP
    WHERE vendorcode = p_vendorcode 
      AND platform = p_platform_code
      AND end_date IS NULL;
    
    -- Создаем новую запись с новой себестоимостью
    INSERT INTO public.cost_price (vendorcode, platform, cost_value, beg_date, end_date)
    VALUES (p_vendorcode, p_platform_code, p_new_cost, p_start_date, NULL);
    
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
'Update cost price for any platform. First record can have any date.';

COMMIT;