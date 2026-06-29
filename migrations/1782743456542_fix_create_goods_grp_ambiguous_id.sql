-- ============================================================================
-- Migration: fix_create_goods_grp_ambiguous_id
-- Description: Fix ambiguous id reference in create_goods_grp function
-- ============================================================================

BEGIN;

DROP FUNCTION IF EXISTS create_goods_grp(VARCHAR(255), TEXT, VARCHAR(255), TEXT, BOOLEAN, INTEGER);

CREATE OR REPLACE FUNCTION create_goods_grp(
    p_name_ru VARCHAR(255),
    p_description_ru TEXT,
    p_name_en VARCHAR(255) DEFAULT NULL,
    p_description_en TEXT DEFAULT NULL,
    p_active BOOLEAN DEFAULT TRUE,
    p_goods_type_id INTEGER DEFAULT NULL
)
RETURNS TABLE (
    id INTEGER,
    active BOOLEAN,
    name_ru VARCHAR(255),
    description_ru TEXT,
    name_en VARCHAR(255),
    description_en TEXT,
    goods_type_id INTEGER
) LANGUAGE plpgsql AS $$
DECLARE
    v_goods_grp_id INTEGER;
BEGIN
    -- Вставляем и получаем ID (явно указываем таблицу)
    INSERT INTO goods_grp (active, goods_type_id) 
    VALUES (p_active, p_goods_type_id)
    RETURNING goods_grp.id INTO v_goods_grp_id;
    
    -- Вставляем русскую локализацию
    INSERT INTO goods_grp_loc (goods_grp_id, locale, name, description)
    VALUES (v_goods_grp_id, 'ru', p_name_ru, COALESCE(p_description_ru, ''));
    
    -- Вставляем английскую локализацию (если есть)
    IF p_name_en IS NOT NULL AND p_name_en != '' THEN
        INSERT INTO goods_grp_loc (goods_grp_id, locale, name, description)
        VALUES (v_goods_grp_id, 'en', p_name_en, COALESCE(p_description_en, p_description_ru, ''));
    END IF;
    
    -- Возвращаем результат
    RETURN QUERY
    SELECT 
        g.id,
        g.active,
        COALESCE(ru.name, '')::VARCHAR(255),
        COALESCE(ru.description, ''),
        COALESCE(en.name, '')::VARCHAR(255),
        COALESCE(en.description, ''),
        g.goods_type_id
    FROM goods_grp g
    LEFT JOIN goods_grp_loc ru ON g.id = ru.goods_grp_id AND ru.locale = 'ru'
    LEFT JOIN goods_grp_loc en ON g.id = en.goods_grp_id AND en.locale = 'en'
    WHERE g.id = v_goods_grp_id;
END;
$$;

COMMENT ON FUNCTION create_goods_grp(VARCHAR(255), TEXT, VARCHAR(255), TEXT, BOOLEAN, INTEGER) IS 
'Create a new goods group with localization. Returns the created group.';

COMMIT;

-- Rollback:
-- BEGIN;
-- DROP FUNCTION IF EXISTS create_goods_grp(VARCHAR(255), TEXT, VARCHAR(255), TEXT, BOOLEAN, INTEGER);
-- CREATE OR REPLACE FUNCTION create_goods_grp(...) ... (previous version);
-- COMMIT;