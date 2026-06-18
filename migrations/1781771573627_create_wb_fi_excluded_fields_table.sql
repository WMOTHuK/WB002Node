-- ============================================================================
-- Migration: create_wb_fi_excluded_fields_table
-- Description: Configuration table for fields excluded from rule-based processing
-- ============================================================================

BEGIN;

CREATE TABLE IF NOT EXISTS wb_fi_excluded_fields (
    id              SERIAL PRIMARY KEY,
    field_name      VARCHAR(50) NOT NULL UNIQUE,
    reason          TEXT,
    is_active       BOOLEAN DEFAULT TRUE,
    created_at      TIMESTAMP DEFAULT NOW()
);

COMMENT ON TABLE wb_fi_excluded_fields IS 'Fields excluded from automatic rule-based processing';

-- Insert default excluded fields
INSERT INTO wb_fi_excluded_fields (field_name, reason) VALUES
    ('user_id', 'System field - part of primary key'),
    ('report_id', 'System field - part of primary key'),
    ('created_at', 'System field - auto-generated'),
    ('updated_at', 'System field - auto-generated'),
    ('overheads', 'Complex calculation - handled separately'),
    ('report_totals', 'Complex calculation - handled separately');

COMMIT;

-- Rollback:
-- BEGIN;
-- DROP TABLE IF EXISTS wb_fi_excluded_fields;
-- COMMIT;