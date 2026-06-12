-- ============================================================================
-- Migration: rename_crm_columns_and_create_views
-- ============================================================================

BEGIN;

-- Rename column in crm_type (safe to run multiple times)
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'crm_type' AND column_name = 'description'
    ) THEN
        ALTER TABLE crm_type RENAME COLUMN description TO crm_type_desc;
    END IF;
END $$;

-- Rename column in crm_status (safe to run multiple times)
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'crm_status' AND column_name = 'description'
    ) THEN
        ALTER TABLE crm_status RENAME COLUMN description TO crm_status_desc;
    END IF;
END $$;

-- Create full view (safe - uses CREATE OR REPLACE)
CREATE OR REPLACE VIEW crm_headers_view AS
SELECT 
    h.advertid,
    h.crmname,
    h.crmtype,
    t.crm_type_desc,
    h.crmstatus,
    s.crm_status_desc,
    h.crmsps,
    h.crmpt,
    h.pause_time,
    h.restart_time,
    h.active,
    h.last_updated,
    h.user_id
FROM crm_headers h
LEFT JOIN crm_type t ON h.crmtype = t.crmtype
LEFT JOIN crm_status s ON h.crmstatus = s.crmstatus;

-- Create simple view (safe - uses CREATE OR REPLACE)
CREATE OR REPLACE VIEW crm_headers_simple_view AS
SELECT 
    h.advertid,
    h.crmname,
    h.crmtype,
    t.crm_type_desc,
    h.crmstatus,
    s.crm_status_desc,
    h.user_id
FROM crm_headers h
LEFT JOIN crm_type t ON h.crmtype = t.crmtype
LEFT JOIN crm_status s ON h.crmstatus = s.crmstatus;

COMMIT;