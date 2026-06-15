-- ============================================================================
-- Migration: create_wb_fi_report_headers_table
-- Description: Table for storing Wildberries financial report headers
-- ============================================================================

BEGIN;

-- Create table without separate id (composite primary key)
CREATE TABLE IF NOT EXISTS wb_fi_report_headers (
    user_id         INTEGER NOT NULL,
    report_id       BIGINT NOT NULL,
    seller_finance_name VARCHAR(255),
    date_from       DATE NOT NULL,
    date_to         DATE NOT NULL,
    create_date     DATE NOT NULL,
    currency        VARCHAR(3) NOT NULL DEFAULT 'RUB',
    report_type     INTEGER NOT NULL,
    retail_amount_sum NUMERIC(15,2) DEFAULT 0,
    for_pay_sum     NUMERIC(15,2) DEFAULT 0,
    avg_sale_percent NUMERIC(10,2) DEFAULT 0,
    delivery_service_sum NUMERIC(15,2) DEFAULT 0,
    paid_storage_sum NUMERIC(15,2) DEFAULT 0,
    paid_acceptance_sum NUMERIC(15,2) DEFAULT 0,
    deduction_sum   NUMERIC(15,2) DEFAULT 0,
    penalty_sum     NUMERIC(15,2) DEFAULT 0,
    additional_payment_sum NUMERIC(15,2) DEFAULT 0,
    cashback_amount_sum NUMERIC(15,2) DEFAULT 0,
    cashback_discount_sum NUMERIC(15,2) DEFAULT 0,
    cashback_commission_change_sum NUMERIC(15,2) DEFAULT 0,
    payment_schedule VARCHAR(10),
    bank_payment_sum NUMERIC(15,2) DEFAULT 0,
    created_at      TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMP NOT NULL DEFAULT NOW(),
    
    -- Composite primary key
    CONSTRAINT wb_fi_report_headers_pkey PRIMARY KEY (user_id, report_id),
    CONSTRAINT wb_fi_report_headers_user_fk FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
    CONSTRAINT wb_fi_report_headers_check_dates CHECK (date_from <= date_to)
);

-- Create indexes
CREATE INDEX idx_wb_fi_report_headers_report_id ON wb_fi_report_headers(report_id);
CREATE INDEX idx_wb_fi_report_headers_date_from ON wb_fi_report_headers(date_from);
CREATE INDEX idx_wb_fi_report_headers_date_to ON wb_fi_report_headers(date_to);
CREATE INDEX idx_wb_fi_report_headers_create_date ON wb_fi_report_headers(create_date);
CREATE INDEX idx_wb_fi_report_headers_user_date ON wb_fi_report_headers(user_id, date_from, date_to);

-- Add comments
COMMENT ON TABLE wb_fi_report_headers IS 'Wildberries financial report headers from marketplace API';
COMMENT ON COLUMN wb_fi_report_headers.user_id IS 'User reference (from users table)';
COMMENT ON COLUMN wb_fi_report_headers.report_id IS 'Unique report identifier from Wildberries';
COMMENT ON COLUMN wb_fi_report_headers.seller_finance_name IS 'Seller legal entity name';
COMMENT ON COLUMN wb_fi_report_headers.date_from IS 'Report period start date';
COMMENT ON COLUMN wb_fi_report_headers.date_to IS 'Report period end date';
COMMENT ON COLUMN wb_fi_report_headers.create_date IS 'Report creation date';
COMMENT ON COLUMN wb_fi_report_headers.currency IS 'Report currency (RUB, USD, etc.)';
COMMENT ON COLUMN wb_fi_report_headers.report_type IS 'Report type (1 = standard, etc.)';
COMMENT ON COLUMN wb_fi_report_headers.retail_amount_sum IS 'Total retail amount';
COMMENT ON COLUMN wb_fi_report_headers.for_pay_sum IS 'Amount to be paid';
COMMENT ON COLUMN wb_fi_report_headers.avg_sale_percent IS 'Average sale percentage';
COMMENT ON COLUMN wb_fi_report_headers.delivery_service_sum IS 'Delivery service costs';
COMMENT ON COLUMN wb_fi_report_headers.paid_storage_sum IS 'Storage costs';
COMMENT ON COLUMN wb_fi_report_headers.paid_acceptance_sum IS 'Acceptance costs';
COMMENT ON COLUMN wb_fi_report_headers.deduction_sum IS 'Deductions amount';
COMMENT ON COLUMN wb_fi_report_headers.penalty_sum IS 'Penalties amount';
COMMENT ON COLUMN wb_fi_report_headers.additional_payment_sum IS 'Additional payments';
COMMENT ON COLUMN wb_fi_report_headers.cashback_amount_sum IS 'Cashback amount';
COMMENT ON COLUMN wb_fi_report_headers.cashback_discount_sum IS 'Cashback discount';
COMMENT ON COLUMN wb_fi_report_headers.cashback_commission_change_sum IS 'Cashback commission change';
COMMENT ON COLUMN wb_fi_report_headers.payment_schedule IS 'Payment schedule type';
COMMENT ON COLUMN wb_fi_report_headers.bank_payment_sum IS 'Bank payment amount';

-- Create trigger for updated_at
CREATE OR REPLACE FUNCTION update_wb_fi_report_headers_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_wb_fi_report_headers_updated_at
    BEFORE UPDATE ON wb_fi_report_headers
    FOR EACH ROW
    EXECUTE FUNCTION update_wb_fi_report_headers_updated_at();

COMMIT;

-- Rollback:
-- BEGIN;
-- DROP TRIGGER IF EXISTS trigger_wb_fi_report_headers_updated_at ON wb_fi_report_headers;
-- DROP FUNCTION IF EXISTS update_wb_fi_report_headers_updated_at();
-- DROP TABLE IF EXISTS wb_fi_report_headers;
-- COMMIT;