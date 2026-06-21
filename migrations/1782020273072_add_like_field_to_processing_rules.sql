-- ============================================================================
-- Migration: add_like_field_to_processing_rules
-- Description: Add like_field column to specify which field to apply LIKE
-- ============================================================================

BEGIN;

-- Добавить колонку
ALTER TABLE wb_fi_processing_rules 
ADD COLUMN like_field VARCHAR(50);

COMMENT ON COLUMN wb_fi_processing_rules.like_field IS 'Field to apply LIKE pattern: doc_type_name, seller_oper_name, bonus_type_name';

COMMIT;