-- ============================================================================
-- Migration: create_wb_fi_report_product_summary_table
-- Description: Create table for product-level financial report summary
-- ============================================================================

BEGIN;

-- Create table
CREATE TABLE IF NOT EXISTS wb_fi_report_product_summary (
    -- Primary key
    user_id                 INTEGER NOT NULL,
    report_id               BIGINT NOT NULL,
    nm_id                   BIGINT NOT NULL,
    
    -- Revenue and payments
    revenue                 NUMERIC(15,2) DEFAULT 0,
    for_pay                 NUMERIC(15,2) DEFAULT 0,
    
    -- Returns
    payback_for_return      NUMERIC(15,2) DEFAULT 0,
    
    -- Logistics totals
    logistics_total         NUMERIC(15,2) DEFAULT 0,
    logistics_to_client_sale        NUMERIC(15,2) DEFAULT 0,
    logistics_to_client_cancel      NUMERIC(15,2) DEFAULT 0,
    logistics_to_seller_callback    NUMERIC(15,2) DEFAULT 0,
    logistics_to_seller_defect      NUMERIC(15,2) DEFAULT 0,
    logistics_from_client_cancel    NUMERIC(15,2) DEFAULT 0,
    logistics_from_client_return    NUMERIC(15,2) DEFAULT 0,
    logistics_correction    NUMERIC(15,2) DEFAULT 0,
    
    -- Other costs
    advertising             NUMERIC(15,2) DEFAULT 0,
    storage                 NUMERIC(15,2) DEFAULT 0,
    fines                   NUMERIC(15,2) DEFAULT 0,
    acceptance              NUMERIC(15,2) DEFAULT 0,
    transit                 NUMERIC(15,2) DEFAULT 0,
    disposal                NUMERIC(15,2) DEFAULT 0,
    loss_compensation       NUMERIC(15,2) DEFAULT 0,
    freewill_compensation   NUMERIC(15,2) DEFAULT 0,
    
    -- Product costs
    cost_price              NUMERIC(15,2) DEFAULT 0,
    seller_tax              NUMERIC(15,2) DEFAULT 0,
    
    -- Additional fields
    overheads               NUMERIC(15,2) DEFAULT 0,
    report_totals           NUMERIC(15,2) DEFAULT 0,
    
    -- Quantity and volume
    quantity                NUMERIC(15,3) DEFAULT 0,
    volume                  NUMERIC(15,2) DEFAULT 0,
    
    -- System fields
    created_at              TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMP NOT NULL DEFAULT NOW(),
    
    -- Constraints
    CONSTRAINT wb_fi_report_product_summary_pkey 
        PRIMARY KEY (user_id, report_id, nm_id)
);

-- Create indexes
CREATE INDEX idx_wb_fi_report_product_summary_report_id 
    ON wb_fi_report_product_summary(report_id);
CREATE INDEX idx_wb_fi_report_product_summary_nm_id 
    ON wb_fi_report_product_summary(nm_id);
CREATE INDEX idx_wb_fi_report_product_summary_user_report 
    ON wb_fi_report_product_summary(user_id, report_id);

-- Add comments
COMMENT ON TABLE wb_fi_report_product_summary IS 
    'Product-level aggregated financial report summary data';
COMMENT ON COLUMN wb_fi_report_product_summary.user_id IS 'User reference (part of composite PK)';
COMMENT ON COLUMN wb_fi_report_product_summary.report_id IS 'Report ID (part of composite PK)';
COMMENT ON COLUMN wb_fi_report_product_summary.nm_id IS 'Product ID (part of composite PK)';
COMMENT ON COLUMN wb_fi_report_product_summary.quantity IS 'Total quantity sold (weight: 15, scale: 3)';
COMMENT ON COLUMN wb_fi_report_product_summary.volume IS 'Total volume in liters (weight: 15, scale: 2)';

-- Create trigger for updated_at
CREATE OR REPLACE FUNCTION update_wb_fi_report_product_summary_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_wb_fi_report_product_summary_updated_at
    BEFORE UPDATE ON wb_fi_report_product_summary
    FOR EACH ROW
    EXECUTE FUNCTION update_wb_fi_report_product_summary_updated_at();

COMMIT;

-- Rollback:
-- BEGIN;
-- DROP TRIGGER IF EXISTS trigger_wb_fi_report_product_summary_updated_at 
--     ON wb_fi_report_product_summary;
-- DROP FUNCTION IF EXISTS update_wb_fi_report_product_summary_updated_at();
-- DROP TABLE IF EXISTS wb_fi_report_product_summary;
-- COMMIT;