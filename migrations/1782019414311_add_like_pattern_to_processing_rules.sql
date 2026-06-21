-- ============================================================================
-- Migration: add_like_pattern_to_processing_rules
-- Description: Add like_pattern column to support LIKE matching
-- ============================================================================

BEGIN;

-- Добавить колонку для хранения LIKE паттерна
ALTER TABLE wb_fi_processing_rules 
ADD COLUMN like_pattern VARCHAR(255);

-- Добавить комментарий
COMMENT ON COLUMN wb_fi_processing_rules.like_pattern IS 'LIKE pattern for matching (e.g., "Отчет об утилизированном товаре%")';

-- Обновить правило для disposal
UPDATE wb_fi_processing_rules 
SET like_pattern = 'Отчет об утилизированном товаре%'
WHERE target_field = 'disposal' 
  AND bonus_type_name = 'Отчет об утилизированном товаре (по складу)';

COMMIT;

-- Rollback:
-- BEGIN;
-- ALTER TABLE wb_fi_processing_rules DROP COLUMN IF EXISTS like_pattern;
-- COMMIT;