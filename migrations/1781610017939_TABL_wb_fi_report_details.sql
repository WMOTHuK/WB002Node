-- ============================================================================
-- Migration: create_wb_fi_report_details_table
-- Description: Table for Wildberries financial report details (line items)
-- ============================================================================

BEGIN;

-- Create table
CREATE TABLE IF NOT EXISTS wb_fi_report_details (
    -- Primary key fields
    user_id                 INTEGER NOT NULL,
    report_id               BIGINT NOT NULL,
    rrd_id                  BIGINT NOT NULL,
    
    -- Report header fields (denormalized for convenience)
    date_from               DATE NOT NULL,
    date_to                 DATE NOT NULL,
    create_date             DATE NOT NULL,
    currency                VARCHAR(3) NOT NULL DEFAULT 'RUB',
    report_type             INTEGER NOT NULL,
    
    -- Product and order fields
    gi_id                   BIGINT,
    dlv_prc                 NUMERIC(15,4),
    fix_tariff_date_from    DATE,
    fix_tariff_date_to      DATE,
    subject_name            VARCHAR(255),
    nm_id                   BIGINT,
    brand_name              VARCHAR(255),
    vendor_code             VARCHAR(50),
    tech_size               VARCHAR(50),
    sku                     VARCHAR(50),
    doc_type_name           VARCHAR(100),
    quantity                INTEGER DEFAULT 0,
    retail_price            NUMERIC(15,2),
    retail_amount           NUMERIC(15,2),
    sale_percent            NUMERIC(10,2),
    commission_percent      NUMERIC(10,2),
    office_name             VARCHAR(255),
    seller_oper_name        VARCHAR(100),
    order_dt                TIMESTAMP,
    sale_dt                 TIMESTAMP,
    rr_date                 DATE,
    shk_id                  BIGINT,
    retail_price_with_disc  NUMERIC(15,2),
    delivery_amount         NUMERIC(15,2),
    return_amount           NUMERIC(15,2),
    delivery_service        NUMERIC(15,2),
    gi_box_type_name        VARCHAR(100),
    product_discount_for_report NUMERIC(15,2),
    seller_promo            NUMERIC(15,2),
    spp                     NUMERIC(15,4),
    kvw_base                NUMERIC(15,4),
    kvw                     NUMERIC(15,4),
    sup_rating_up           NUMERIC(15,4),
    is_kgvp_v2              INTEGER,
    ppvz_sales_commission   NUMERIC(15,2),
    for_pay                 NUMERIC(15,2),
    ppvz_reward             NUMERIC(15,2),
    acquiring_fee           NUMERIC(15,2),
    acquiring_percent       NUMERIC(10,4),
    payment_processing      VARCHAR(255),
    acquiring_bank          VARCHAR(100),
    vw                      NUMERIC(15,4),
    vw_nds                  NUMERIC(15,4),
    ppvz_office_name        VARCHAR(255),
    ppvz_office_id          INTEGER,
    ppvz_supplier_name      VARCHAR(255),
    ppvz_supplier_inn       VARCHAR(50),
    declaration_number      VARCHAR(100),
    bonus_type_name         VARCHAR(255),
    sticker_id              VARCHAR(50),
    country                 VARCHAR(100),
    srv_dbs                 BOOLEAN DEFAULT FALSE,
    penalty                 NUMERIC(15,2),
    additional_payment      NUMERIC(15,2),
    rebill_logistic_cost    NUMERIC(15,4),
    rebill_logistic_org     VARCHAR(255),
    paid_storage            NUMERIC(15,2),
    deduction               NUMERIC(15,2),
    paid_acceptance         NUMERIC(15,2),
    order_id                BIGINT,
    kiz                     TEXT,
    is_b2b                  BOOLEAN DEFAULT FALSE,
    trbx_id                 VARCHAR(100),
    installment_cofinancing_amount NUMERIC(15,2),
    wibes_discount_percent  NUMERIC(10,2),
    cashback_amount         NUMERIC(15,2),
    cashback_discount       NUMERIC(15,2),
    cashback_commission_change NUMERIC(15,4),
    payment_schedule        VARCHAR(10),
    delivery_method         VARCHAR(100),
    seller_promo_id         INTEGER,
    seller_promo_discount   NUMERIC(10,2),
    loyalty_id              INTEGER,
    loyalty_discount        NUMERIC(10,2),
    uuid_promocode          VARCHAR(100),
    sale_price_promocode_discount_prc NUMERIC(10,4),
    article_substitution    VARCHAR(100),
    sale_price_affiliated_discount_prc NUMERIC(10,4),
    agency_vat              NUMERIC(10,2),
    sale_price_wholesale_discount_prc NUMERIC(10,4),
    order_uid               VARCHAR(100),
    srid                    VARCHAR(100),
    
    -- System fields
    created_at              TIMESTAMP NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMP NOT NULL DEFAULT NOW(),
    
    -- Composite primary key
    CONSTRAINT wb_fi_report_details_pkey PRIMARY KEY (user_id, report_id, rrd_id),
    
    -- Foreign keys
    CONSTRAINT wb_fi_report_details_type_fk 
        FOREIGN KEY (report_type) REFERENCES wb_fi_report_types(report_type),
    CONSTRAINT wb_fi_report_details_header_fk 
        FOREIGN KEY (user_id, report_id) REFERENCES wb_fi_report_headers(user_id, report_id) ON DELETE CASCADE,
    CONSTRAINT wb_fi_report_details_goods_fk 
        FOREIGN KEY (vendor_code) REFERENCES goods(vendorcode) ON DELETE SET NULL
);

-- Create indexes
CREATE INDEX idx_wb_fi_report_details_report_id ON wb_fi_report_details(report_id);
CREATE INDEX idx_wb_fi_report_details_user_id ON wb_fi_report_details(user_id);
CREATE INDEX idx_wb_fi_report_details_rrd_id ON wb_fi_report_details(rrd_id);
CREATE INDEX idx_wb_fi_report_details_vendor_code ON wb_fi_report_details(vendor_code);
CREATE INDEX idx_wb_fi_report_details_nm_id ON wb_fi_report_details(nm_id);
CREATE INDEX idx_wb_fi_report_details_order_id ON wb_fi_report_details(order_id);
CREATE INDEX idx_wb_fi_report_details_sale_dt ON wb_fi_report_details(sale_dt);
CREATE INDEX idx_wb_fi_report_details_user_report ON wb_fi_report_details(user_id, report_id);
CREATE INDEX idx_wb_fi_report_details_doc_type ON wb_fi_report_details(doc_type_name);

-- Add comments
COMMENT ON TABLE wb_fi_report_details IS 'Wildberries financial report details (line items)';
COMMENT ON COLUMN wb_fi_report_details.user_id IS 'User reference (part of composite PK)';
COMMENT ON COLUMN wb_fi_report_details.report_id IS 'Report ID (part of composite PK)';
COMMENT ON COLUMN wb_fi_report_details.rrd_id IS 'Report row detail ID (part of composite PK)';
COMMENT ON COLUMN wb_fi_report_details.vendor_code IS 'Product vendor code (references goods)';
COMMENT ON COLUMN wb_fi_report_details.report_type IS 'Report type (references wb_fi_report_types)';

-- Create trigger for updated_at
CREATE OR REPLACE FUNCTION update_wb_fi_report_details_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trigger_wb_fi_report_details_updated_at
    BEFORE UPDATE ON wb_fi_report_details
    FOR EACH ROW
    EXECUTE FUNCTION update_wb_fi_report_details_updated_at();

COMMIT;

-- Rollback:
-- BEGIN;
-- DROP TRIGGER IF EXISTS trigger_wb_fi_report_details_updated_at ON wb_fi_report_details;
-- DROP FUNCTION IF EXISTS update_wb_fi_report_details_updated_at();
-- DROP TABLE IF EXISTS wb_fi_report_details;
-- COMMIT;