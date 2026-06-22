-- ============================================================================
-- Migration: create_calculate_quantity_volume_functions
-- Description: Calculate quantity and volume for sales and returns
-- ============================================================================

BEGIN;

-- 1. Функция для общего quantity и volume
CREATE OR REPLACE FUNCTION calculate_wb_total_quantity_volume(
    p_user_id INTEGER,
    p_report_ids BIGINT[]
)
RETURNS TABLE (
    total_quantity NUMERIC(15,3),
    total_volume NUMERIC(15,2)
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
        ), 0) AS total_volume
    FROM wb_fi_report_details d
    LEFT JOIN goods g ON g.nm_id = d.nm_id
    WHERE d.user_id = p_user_id 
      AND d.report_id = ANY(p_report_ids)
      AND d.nm_id IS NOT NULL
      AND d.nm_id != 0
      AND d.seller_oper_name IN ('Продажа', 'Возврат');
$$;

-- 2. Функция для quantity и volume по товарам
CREATE OR REPLACE FUNCTION calculate_wb_product_quantity_volume(
    p_user_id INTEGER,
    p_report_ids BIGINT[]
)
RETURNS TABLE (
    nm_id BIGINT,
    quantity NUMERIC(15,3),
    volume NUMERIC(15,2)
) LANGUAGE sql STABLE AS $$
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
        ), 0) AS volume
    FROM wb_fi_report_details d
    LEFT JOIN goods g ON g.nm_id = d.nm_id
    WHERE d.user_id = p_user_id 
      AND d.report_id = ANY(p_report_ids)
      AND d.nm_id IS NOT NULL
      AND d.nm_id != 0
      AND d.seller_oper_name IN ('Продажа', 'Возврат')
    GROUP BY d.nm_id
    ORDER BY d.nm_id;
$$;

-- 3. Правила для продажи и возврата (обрабатываются, но не влияют на суммы через wb_sum_by_rule)
-- Добавляем правила, чтобы строки не попадали в unmatched
INSERT INTO wb_fi_processing_rules (
    rule_name,
    seller_oper_name,
    action,
    target_field,
    amount_source,
    priority
) VALUES 
    ('Quantity - Продажа', 'Продажа', 'skip', NULL, NULL, 15),
    ('Quantity - Возврат', 'Возврат', 'skip', NULL, NULL, 16)
ON CONFLICT DO NOTHING;

COMMIT;

-- Rollback:
-- BEGIN;
-- DELETE FROM wb_fi_processing_rules 
-- WHERE seller_oper_name IN ('Продажа', 'Возврат') AND action = 'skip';
-- DROP FUNCTION IF EXISTS calculate_wb_total_quantity_volume(INTEGER, BIGINT[]);
-- DROP FUNCTION IF EXISTS calculate_wb_product_quantity_volume(INTEGER, BIGINT[]);
-- COMMIT;