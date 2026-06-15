-- ============================================================================
-- Migration: create_wb_fi_report_types_table
-- Description: Lookup table for Wildberries financial report types
-- ============================================================================

BEGIN;

-- Create table
CREATE TABLE IF NOT EXISTS wb_fi_report_types (
    report_type     INTEGER PRIMARY KEY,
    report_type_name VARCHAR(100) NOT NULL,
    description     TEXT,
    created_at      TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Add comments
COMMENT ON TABLE wb_fi_report_types IS 'Lookup table for Wildberries financial report types';
COMMENT ON COLUMN wb_fi_report_types.report_type IS 'Report type code (primary key)';
COMMENT ON COLUMN wb_fi_report_types.report_type_name IS 'Report type display name';
COMMENT ON COLUMN wb_fi_report_types.description IS 'Detailed description of report type';

-- Create trigger for updated_at
CREATE OR REPLACE FUNCTION update_wb_fi_report_types_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_wb_fi_report_types_updated_at
    BEFORE UPDATE ON wb_fi_report_types
    FOR EACH ROW
    EXECUTE FUNCTION update_wb_fi_report_types_updated_at();

-- Insert initial data (using DELETE + INSERT to avoid conflicts)
DELETE FROM wb_fi_report_types WHERE report_type IN (1, 2, 3, 4, 5);

INSERT INTO wb_fi_report_types (report_type, report_type_name, description) VALUES
    (1, 'Общий', 'General'),
    (2, 'По выкупам', 'By purchase'),
    (3, 'По выкупам - Грузия', 'By purchase for Georgia');

COMMIT;

-- Rollback:
-- BEGIN;
-- DROP TABLE IF EXISTS wb_fi_report_types;
-- DROP FUNCTION IF EXISTS update_wb_fi_report_types_updated_at();
-- COMMIT;