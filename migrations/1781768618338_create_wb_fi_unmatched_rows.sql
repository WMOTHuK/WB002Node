-- ============================================================================
-- Migration: create_wb_fi_unmatched_rows
-- Description: Table for rows that couldn't be processed
-- ============================================================================

BEGIN;

CREATE TABLE IF NOT EXISTS wb_fi_unmatched_rows (
    id              SERIAL PRIMARY KEY,
    user_id         INTEGER NOT NULL,
    report_id       BIGINT NOT NULL,
    row_data        JSONB NOT NULL,
    reason          TEXT,
    created_at      TIMESTAMP DEFAULT NOW()
);

COMMENT ON TABLE wb_fi_unmatched_rows IS 'Rows that couldn''t be matched to any processing rule';
COMMENT ON COLUMN wb_fi_unmatched_rows.row_data IS 'Full row data as JSON';
COMMENT ON COLUMN wb_fi_unmatched_rows.reason IS 'Why it wasn''t processed';

COMMIT;