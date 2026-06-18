-- ============================================================================
-- Migration: create_wb_fi_report_summary_table
-- Description: Table for storing aggregated financial report summary data
-- ============================================================================

BEGIN;

-- Create table
CREATE TABLE IF NOT EXISTS wb_fi_report_summary (
    user_id                 INTEGER NOT NULL,
    report_id               BIGINT NOT NULL,
    
    -- Revenue and payments
    revenue                 NUMERIC(15,2) DEFAULT 0,
    for_pay                 NUMERIC(15,2) DEFAULT 0,
    
    -- Returns
    payback_for_return      NUMERIC(15,2) DEFAULT 0,
    
    -- Logistics totals
    logistics_total         NUMERIC(15,2) DEFAULT 0,
    logistics_to_client_sale        NUMERIC(15,2) DEFAULT 0,
    logistics_to_client_return      NUMERIC(15,2) DEFAULT 0,
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
    
    -- System fields
    created_at              TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMP NOT NULL DEFAULT NOW(),
    
    -- Constraints
    CONSTRAINT wb_fi_report_summary_pkey PRIMARY KEY (user_id, report_id),
    CONSTRAINT wb_fi_report_summary_header_fk 
        FOREIGN KEY (user_id, report_id) 
        REFERENCES wb_fi_report_headers(user_id, report_id) ON DELETE CASCADE
);

-- Create indexes
CREATE INDEX idx_wb_fi_report_summary_report_id ON wb_fi_report_summary(report_id);

-- Add comments
COMMENT ON TABLE wb_fi_report_summary IS 'Aggregated financial report summary data';
COMMENT ON COLUMN wb_fi_report_summary.user_id IS 'User reference (part of composite PK)';
COMMENT ON COLUMN wb_fi_report_summary.report_id IS 'Report ID (part of composite PK)';
COMMENT ON COLUMN wb_fi_report_summary.revenue IS 'Revenue (выручка)';
COMMENT ON COLUMN wb_fi_report_summary.for_pay IS 'Amount to pay (к оплате)';
COMMENT ON COLUMN wb_fi_report_summary.payback_for_return IS 'Payback for returns (возврат за возвраты)';
COMMENT ON COLUMN wb_fi_report_summary.logistics_total IS 'Total logistics costs (всего логистика)';
COMMENT ON COLUMN wb_fi_report_summary.logistics_to_client_sale IS 'Logistics to client - sale';
COMMENT ON COLUMN wb_fi_report_summary.logistics_to_client_return IS 'Logistics to client - return';
COMMENT ON COLUMN wb_fi_report_summary.logistics_to_seller_callback IS 'Logistics to seller - callback';
COMMENT ON COLUMN wb_fi_report_summary.logistics_to_seller_defect IS 'Logistics to seller - defect';
COMMENT ON COLUMN wb_fi_report_summary.logistics_from_client_cancel IS 'Logistics from client - cancel';
COMMENT ON COLUMN wb_fi_report_summary.logistics_from_client_return IS 'Logistics from client - return';
COMMENT ON COLUMN wb_fi_report_summary.logistics_correction IS 'Logistics correction';
COMMENT ON COLUMN wb_fi_report_summary.advertising IS 'Advertising costs (реклама)';
COMMENT ON COLUMN wb_fi_report_summary.storage IS 'Storage costs (хранение)';
COMMENT ON COLUMN wb_fi_report_summary.fines IS 'Fines (штрафы)';
COMMENT ON COLUMN wb_fi_report_summary.acceptance IS 'Acceptance costs (приёмка)';
COMMENT ON COLUMN wb_fi_report_summary.transit IS 'Transit costs (транзит)';
COMMENT ON COLUMN wb_fi_report_summary.disposal IS 'Disposal costs (утилизация)';
COMMENT ON COLUMN wb_fi_report_summary.loss_compensation IS 'Loss compensation (компенсация потерь)';
COMMENT ON COLUMN wb_fi_report_summary.freewill_compensation IS 'Freewill compensation (добровольная компенсация)';
COMMENT ON COLUMN wb_fi_report_summary.cost_price IS 'Cost of goods sold (себестоимость товаров)';
COMMENT ON COLUMN wb_fi_report_summary.seller_tax IS 'Seller tax (налог продавца)';
COMMENT ON COLUMN wb_fi_report_summary.overheads IS 'Overhead expenses (накладные расходы)';
COMMENT ON COLUMN wb_fi_report_summary.report_totals IS 'Report totals (итоги по отчёту)';

-- Create trigger for updated_at
CREATE OR REPLACE FUNCTION update_wb_fi_report_summary_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_wb_fi_report_summary_updated_at
    BEFORE UPDATE ON wb_fi_report_summary
    FOR EACH ROW
    EXECUTE FUNCTION update_wb_fi_report_summary_updated_at();

COMMIT;

-- Rollback:
-- BEGIN;
-- DROP TRIGGER IF EXISTS trigger_wb_fi_report_summary_updated_at ON wb_fi_report_summary;
-- DROP FUNCTION IF EXISTS update_wb_fi_report_summary_updated_at();
-- DROP TABLE IF EXISTS wb_fi_report_summary;
-- COMMIT;