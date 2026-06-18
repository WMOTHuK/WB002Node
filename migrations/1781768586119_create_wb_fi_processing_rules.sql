-- ============================================================================
-- Migration: create_wb_fi_processing_rules
-- Description: Rules for processing financial report details
-- ============================================================================

BEGIN;

CREATE TABLE IF NOT EXISTS wb_fi_processing_rules (
    id                  SERIAL PRIMARY KEY,
    rule_name           VARCHAR(100) NOT NULL,
    doc_type_name       VARCHAR(100),              -- NULL = any
    seller_oper_name    VARCHAR(100),              -- NULL = any
    bonus_type_name     VARCHAR(255),              -- NULL = any
    action              VARCHAR(20) NOT NULL,      -- 'add', 'subtract', 'skip'
    target_field        VARCHAR(50),               -- Summary field name
    amount_source       VARCHAR(50) DEFAULT 'for_pay', -- Field to sum
    priority            INTEGER DEFAULT 100,
    is_active           BOOLEAN DEFAULT TRUE,
    created_at          TIMESTAMP DEFAULT NOW(),
    updated_at          TIMESTAMP DEFAULT NOW()
);

COMMENT ON TABLE wb_fi_processing_rules IS 'Rules for processing financial report detail rows';
COMMENT ON COLUMN wb_fi_processing_rules.doc_type_name IS 'Document type (NULL = any)';
COMMENT ON COLUMN wb_fi_processing_rules.seller_oper_name IS 'Seller operation name (NULL = any)';
COMMENT ON COLUMN wb_fi_processing_rules.bonus_type_name IS 'Bonus type (NULL = any)';
COMMENT ON COLUMN wb_fi_processing_rules.action IS 'Action: add, subtract, skip';
COMMENT ON COLUMN wb_fi_processing_rules.target_field IS 'Target summary field';
COMMENT ON COLUMN wb_fi_processing_rules.amount_source IS 'Source field for amount';
COMMENT ON COLUMN wb_fi_processing_rules.priority IS 'Rule priority (lower = higher)';

-- Trigger for updated_at
CREATE OR REPLACE FUNCTION update_wb_fi_processing_rules_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_wb_fi_processing_rules_updated_at
    BEFORE UPDATE ON wb_fi_processing_rules
    FOR EACH ROW
    EXECUTE FUNCTION update_wb_fi_processing_rules_updated_at();

COMMIT;
