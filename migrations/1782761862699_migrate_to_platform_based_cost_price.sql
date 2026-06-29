-- ============================================================================
-- Migration: migrate_to_platform_based_cost_price
-- Description: Convert cost_price to platform-based structure
-- ============================================================================

BEGIN;

-- ============================================================================
-- 1. Проверяем существование таблицы gen_platforms с нужными платформами
-- ============================================================================

INSERT INTO gen_platforms (code, name) VALUES
    ('wb', 'Wildberries'),
    ('ozon', 'Ozon')
ON CONFLICT (code) DO UPDATE SET name = EXCLUDED.name;

-- ============================================================================
-- 2. Создаём новую таблицу cost_price_new
-- ============================================================================

CREATE TABLE cost_price_new (
    vendorcode  VARCHAR(10) NOT NULL,
    platform    VARCHAR(10) NOT NULL,
    cost_value  NUMERIC(12,2) NOT NULL,
    beg_date    DATE NOT NULL,
    end_date    DATE,
    created_at  TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at  TIMESTAMP NOT NULL DEFAULT NOW(),
    PRIMARY KEY (vendorcode, platform, beg_date),
    CONSTRAINT fk_cost_price_goods FOREIGN KEY (vendorcode) REFERENCES goods(vendorcode) ON DELETE CASCADE,
    CONSTRAINT fk_cost_price_platform FOREIGN KEY (platform) REFERENCES gen_platforms(code) ON DELETE RESTRICT
);

-- ============================================================================
-- 3. Переносим данные из старой структуры
-- ============================================================================

-- Переносим WB данные
INSERT INTO cost_price_new (vendorcode, platform, cost_value, beg_date, end_date, created_at, updated_at)
SELECT 
    vendorcode, 
    'wb', 
    wb_cost_value, 
    beg_date, 
    end_date,
    created_at,
    updated_at
FROM cost_price
WHERE wb_cost_value IS NOT NULL;

-- Переносим Ozon данные
INSERT INTO cost_price_new (vendorcode, platform, cost_value, beg_date, end_date, created_at, updated_at)
SELECT 
    vendorcode, 
    'ozon', 
    ozon_cost_value, 
    beg_date, 
    end_date,
    created_at,
    updated_at
FROM cost_price
WHERE ozon_cost_value IS NOT NULL;

-- ============================================================================
-- 4. Удаляем старую таблицу и переименовываем новую
-- ============================================================================

DROP TABLE cost_price CASCADE;
ALTER TABLE cost_price_new RENAME TO cost_price;

-- ============================================================================
-- 5. Создаём индексы
-- ============================================================================

CREATE INDEX idx_cost_price_vendorcode ON cost_price(vendorcode);
CREATE INDEX idx_cost_price_platform ON cost_price(platform);
CREATE INDEX idx_cost_price_dates ON cost_price(beg_date, end_date);
CREATE INDEX idx_cost_price_vendor_platform ON cost_price(vendorcode, platform);
CREATE INDEX idx_cost_price_active ON cost_price(vendorcode, platform, end_date) WHERE end_date IS NULL;

-- ============================================================================
-- 6. Создаём триггер для updated_at
-- ============================================================================

CREATE OR REPLACE FUNCTION update_cost_price_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_cost_price_updated_at
    BEFORE UPDATE ON cost_price
    FOR EACH ROW
    EXECUTE FUNCTION update_cost_price_updated_at();

-- ============================================================================
-- 7. Создаём универсальную функцию update_cost_price
-- ============================================================================

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
    platform VARCHAR(10),
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
            NULL::VARCHAR(10), NULL::NUMERIC, NULL::NUMERIC, NULL::DATE, NULL::DATE;
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
            NULL::VARCHAR(10), NULL::NUMERIC, NULL::NUMERIC, NULL::DATE, NULL::DATE;
        RETURN;
    END IF;
    
    -- Проверяем, что новая дата не раньше текущей
    IF p_start_date <= CURRENT_DATE THEN
        RETURN QUERY SELECT 
            'ERROR'::TEXT, 
            'Дата начала должна быть больше текущей даты'::TEXT,
            p_platform_code, NULL::NUMERIC, NULL::NUMERIC, NULL::DATE, NULL::DATE;
        RETURN;
    END IF;
    
    -- Находим текущую активную себестоимость для указанной платформы
    SELECT cost_value, beg_date INTO v_current_cost, v_current_beg_date
    FROM public.cost_price
    WHERE vendorcode = p_vendorcode 
      AND platform = p_platform_code
      AND end_date IS NULL
    FOR UPDATE;
    
    -- Если текущей себестоимости нет, создаем первую запись
    IF v_current_cost IS NULL THEN
        INSERT INTO public.cost_price (vendorcode, platform, cost_value, beg_date, end_date)
        VALUES (p_vendorcode, p_platform_code, p_new_cost, p_start_date, NULL);
        
        RETURN QUERY SELECT 
            'SUCCESS'::TEXT, 
            'Создана новая себестоимость для ' || v_platform_name || ' (активная запись отсутствовала)'::TEXT,
            p_platform_code, NULL::NUMERIC, p_new_cost, p_start_date, NULL::DATE;
        RETURN;
    END IF;
    
    -- Проверяем, не пытаемся ли установить ту же себестоимость
    IF v_current_cost = p_new_cost THEN
        RETURN QUERY SELECT 
            'WARNING'::TEXT, 
            'Себестоимость для ' || v_platform_name || ' не изменилась, обновление не требуется'::TEXT,
            p_platform_code, v_current_cost, p_new_cost, NULL::DATE, NULL::DATE;
        RETURN;
    END IF;
    
    -- Основная логика: закрываем текущий период и создаем новый
    v_previous_end_date := p_start_date - INTERVAL '1 day';
    
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
        p_platform_code, v_current_cost, p_new_cost, p_start_date, v_previous_end_date;
        
EXCEPTION
    WHEN OTHERS THEN
        RETURN QUERY SELECT 
            'ERROR'::TEXT, 
            'Ошибка: ' || SQLERRM::TEXT,
            p_platform_code, NULL::NUMERIC, NULL::NUMERIC, NULL::DATE, NULL::DATE;
END;
$$ LANGUAGE plpgsql;

COMMENT ON FUNCTION update_cost_price(VARCHAR(10), VARCHAR(10), NUMERIC(12,2), DATE) IS 
'Update cost price for any platform (wb, ozon, etc.).';

-- ============================================================================
-- 8. Обновляем product_data view
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
    (SELECT cost_value FROM cost_price cp WHERE cp.vendorcode = g.vendorcode AND cp.platform = 'wb' AND cp.end_date IS NULL) AS wb_current_cost,
    (SELECT cost_value FROM cost_price cp WHERE cp.vendorcode = g.vendorcode AND cp.platform = 'ozon' AND cp.end_date IS NULL) AS ozon_current_cost,
    '2026-01-01'::DATE AS change_date,
    g.deleted,
    COALESCE(gt.name_ru, '') AS goods_type_name,
    g.goods_grp_id,
    COALESCE(gg.name_ru, '') AS goods_grp_name
FROM goods g
LEFT JOIN goods_grp_active_multilang gg ON g.goods_grp_id = gg.id
LEFT JOIN goods_type_active_multilang gt ON gg.goods_type_id = gt.id
ORDER BY g.vendorcode;

COMMENT ON VIEW product_data IS 'Products with separate cost prices for each platform';

-- ============================================================================
-- 9. Добавляем комментарии
-- ============================================================================

COMMENT ON TABLE cost_price IS 'Cost prices for products by platform with validity periods';
COMMENT ON COLUMN cost_price.vendorcode IS 'Product vendor code';
COMMENT ON COLUMN cost_price.platform IS 'Platform code (wb, ozon, etc.)';
COMMENT ON COLUMN cost_price.cost_value IS 'Cost price value';
COMMENT ON COLUMN cost_price.beg_date IS 'Date from which this cost is valid';
COMMENT ON COLUMN cost_price.end_date IS 'Date until which this cost is valid (NULL = currently active)';

COMMIT;