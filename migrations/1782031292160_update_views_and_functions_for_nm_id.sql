-- ============================================================================
-- Migration: update_views_and_functions_for_nm_id
-- Description: Update views and functions to use nm_id instead of nmid
-- ============================================================================

BEGIN;

-- 1. Пересоздать VIEW product_data
DROP VIEW IF EXISTS product_data CASCADE;

CREATE VIEW product_data AS
SELECT 
    g.card_photo,
    g.title,
    g.vendorcode,
    g.nm_id,
    g.wbvol,
    g.ozid,
    g.ozvol,
    g.imtid,
    cp.cost_value AS current_cost,
    CURRENT_DATE AS change_date,
    g.deleted,
    COALESCE(gt.name_ru, '') AS goods_type_name,
    g.goods_grp_id,
    COALESCE(gg.name_ru, '') AS goods_grp_name
FROM goods g
LEFT JOIN cost_price cp ON cp.vendorcode = g.vendorcode AND cp.end_date IS NULL
LEFT JOIN goods_grp_active_multilang gg ON g.goods_grp_id = gg.id
LEFT JOIN goods_type_active_multilang gt ON gg.goods_type_id = gt.id
ORDER BY g.vendorcode;

-- 2. Удалить функцию get_campaign_assignable_cards (чтобы пересоздать с новым типом)
DROP FUNCTION IF EXISTS get_campaign_assignable_cards(INTEGER);

-- Создать заново
CREATE OR REPLACE FUNCTION get_campaign_assignable_cards(p_advertid INTEGER)
RETURNS TABLE (
    card_photo TEXT,
    nm_id INTEGER,
    vendorcode VARCHAR(10),
    title VARCHAR(100),
    goods_type_id INTEGER,
    goods_type_name VARCHAR(255),
    goods_grp_id INTEGER,
    goods_grp_name VARCHAR(255),
    has_link BOOLEAN
) LANGUAGE sql STABLE AS $$
    SELECT 
        g.card_photo,
        g.nm_id,
        g.vendorcode,
        g.title,
        gg.goods_type_id,
        COALESCE(gt.name_ru, 'Без типа') AS goods_type_name,
        g.goods_grp_id,
        COALESCE(gg.name_ru, 'Без группы') AS goods_grp_name,
        CASE WHEN cs.vendorcode IS NOT NULL THEN TRUE ELSE FALSE END AS has_link
    FROM goods g
    LEFT JOIN goods_grp_active_multilang gg ON g.goods_grp_id = gg.id
    LEFT JOIN goods_type_active_multilang gt ON gg.goods_type_id = gt.id
    LEFT JOIN crm_campaign_subcards cs ON cs.vendorcode = g.vendorcode AND cs.advertid = p_advertid
    WHERE g.nm_id IS NOT NULL 
      AND (g.deleted = FALSE OR g.deleted IS NULL)
    ORDER BY g.vendorcode;
$$;

-- 3. Удалить функцию add_group_cards_to_campaign (зависит от get_campaign_assignable_cards)
DROP FUNCTION IF EXISTS add_group_cards_to_campaign(INTEGER, INTEGER);

CREATE OR REPLACE FUNCTION add_group_cards_to_campaign(
    p_advertid INTEGER,
    p_goods_grp_id INTEGER
)
RETURNS TABLE (
    processed INTEGER,
    inserted INTEGER,
    already_exists INTEGER,
    errors INTEGER
) LANGUAGE plpgsql AS $$
DECLARE
    v_items JSONB;
    v_result RECORD;
BEGIN
    -- Build JSON array of vendorcodes from the group
    SELECT jsonb_agg(
        jsonb_build_object(
            'vendorcode', g.vendorcode,
            'has_link', TRUE
        )
    ) INTO v_items
    FROM goods g
    WHERE g.goods_grp_id = p_goods_grp_id
      AND g.nm_id IS NOT NULL
      AND (g.deleted = FALSE OR g.deleted IS NULL);
    
    -- If no items found, return zeros
    IF v_items IS NULL THEN
        RETURN QUERY SELECT 0::INTEGER, 0::INTEGER, 0::INTEGER, 0::INTEGER;
        RETURN;
    END IF;
    
    -- Reuse sync_campaign_subcards function
    FOR v_result IN 
        SELECT * FROM sync_campaign_subcards(p_advertid, v_items)
    LOOP
        processed := v_result.processed;
        inserted := v_result.inserted;
        already_exists := v_result.processed - v_result.inserted - v_result.errors;
        errors := v_result.errors;
        RETURN NEXT;
    END LOOP;
END;
$$;

-- 4. Удалить и пересоздать sync_wb_fi_report_details
DROP FUNCTION IF EXISTS sync_wb_fi_report_details(INTEGER, JSONB);

CREATE OR REPLACE FUNCTION sync_wb_fi_report_details(
    p_user_id INTEGER,
    p_details JSONB
)
RETURNS TABLE (
    processed INTEGER,
    inserted INTEGER,
    skipped INTEGER,
    errors INTEGER,
    error_details TEXT
) LANGUAGE plpgsql AS $$
DECLARE
    v_detail RECORD;
    v_processed INTEGER := 0;
    v_inserted INTEGER := 0;
    v_skipped INTEGER := 0;
    v_errors INTEGER := 0;
    v_error_details TEXT := '';
    v_rrd_id BIGINT;
BEGIN
    FOR v_detail IN 
        SELECT * FROM jsonb_to_recordset(p_details) AS x(
            report_id BIGINT,
            date_from DATE,
            date_to DATE,
            create_date DATE,
            currency VARCHAR(3),
            report_type INTEGER,
            rrd_id BIGINT,
            gi_id BIGINT,
            dlv_prc NUMERIC(15,4),
            fix_tariff_date_from DATE,
            fix_tariff_date_to DATE,
            subject_name VARCHAR(255),
            nm_id BIGINT,
            brand_name VARCHAR(255),
            vendor_code VARCHAR(50),
            tech_size VARCHAR(50),
            sku VARCHAR(50),
            doc_type_name VARCHAR(100),
            quantity INTEGER,
            retail_price NUMERIC(15,2),
            retail_amount NUMERIC(15,2),
            sale_percent NUMERIC(10,2),
            commission_percent NUMERIC(10,2),
            office_name VARCHAR(255),
            seller_oper_name VARCHAR(100),
            order_dt TIMESTAMP,
            sale_dt TIMESTAMP,
            rr_date DATE,
            shk_id BIGINT,
            retail_price_with_disc NUMERIC(15,2),
            delivery_amount NUMERIC(15,2),
            return_amount NUMERIC(15,2),
            delivery_service NUMERIC(15,2),
            gi_box_type_name VARCHAR(100),
            product_discount_for_report NUMERIC(15,2),
            seller_promo NUMERIC(15,2),
            spp NUMERIC(15,4),
            kvw_base NUMERIC(15,4),
            kvw NUMERIC(15,4),
            sup_rating_up NUMERIC(15,4),
            is_kgvp_v2 INTEGER,
            ppvz_sales_commission NUMERIC(15,2),
            for_pay NUMERIC(15,2),
            ppvz_reward NUMERIC(15,2),
            acquiring_fee NUMERIC(15,2),
            acquiring_percent NUMERIC(10,4),
            payment_processing VARCHAR(255),
            acquiring_bank VARCHAR(100),
            vw NUMERIC(15,4),
            vw_nds NUMERIC(15,4),
            ppvz_office_name VARCHAR(255),
            ppvz_office_id INTEGER,
            ppvz_supplier_name VARCHAR(255),
            ppvz_supplier_inn VARCHAR(50),
            declaration_number VARCHAR(100),
            bonus_type_name VARCHAR(255),
            sticker_id VARCHAR(50),
            country VARCHAR(100),
            srv_dbs BOOLEAN,
            penalty NUMERIC(15,2),
            additional_payment NUMERIC(15,2),
            rebill_logistic_cost NUMERIC(15,4),
            rebill_logistic_org VARCHAR(255),
            paid_storage NUMERIC(15,2),
            deduction NUMERIC(15,2),
            paid_acceptance NUMERIC(15,2),
            order_id BIGINT,
            kiz TEXT,
            is_b2b BOOLEAN,
            trbx_id VARCHAR(100),
            installment_cofinancing_amount NUMERIC(15,2),
            wibes_discount_percent NUMERIC(10,2),
            cashback_amount NUMERIC(15,2),
            cashback_discount NUMERIC(15,2),
            cashback_commission_change NUMERIC(15,4),
            payment_schedule VARCHAR(10),
            delivery_method VARCHAR(100),
            seller_promo_id INTEGER,
            seller_promo_discount NUMERIC(10,2),
            loyalty_id INTEGER,
            loyalty_discount NUMERIC(10,2),
            uuid_promocode VARCHAR(100),
            sale_price_promocode_discount_prc NUMERIC(10,4),
            article_substitution VARCHAR(100),
            sale_price_affiliated_discount_prc NUMERIC(10,4),
            agency_vat NUMERIC(10,2),
            sale_price_wholesale_discount_prc NUMERIC(10,4),
            order_uid VARCHAR(100),
            srid VARCHAR(100)
        )
    LOOP
        v_processed := v_processed + 1;
        v_rrd_id := v_detail.rrd_id;
        
        BEGIN
            INSERT INTO wb_fi_report_details (
                user_id, report_id, rrd_id, date_from, date_to, create_date,
                currency, report_type, gi_id, dlv_prc, fix_tariff_date_from,
                fix_tariff_date_to, subject_name, nm_id, brand_name, vendor_code,
                tech_size, sku, doc_type_name, quantity, retail_price,
                retail_amount, sale_percent, commission_percent, office_name,
                seller_oper_name, order_dt, sale_dt, rr_date, shk_id,
                retail_price_with_disc, delivery_amount, return_amount,
                delivery_service, gi_box_type_name, product_discount_for_report,
                seller_promo, spp, kvw_base, kvw, sup_rating_up, is_kgvp_v2,
                ppvz_sales_commission, for_pay, ppvz_reward, acquiring_fee,
                acquiring_percent, payment_processing, acquiring_bank, vw,
                vw_nds, ppvz_office_name, ppvz_office_id, ppvz_supplier_name,
                ppvz_supplier_inn, declaration_number, bonus_type_name,
                sticker_id, country, srv_dbs, penalty, additional_payment,
                rebill_logistic_cost, rebill_logistic_org, paid_storage,
                deduction, paid_acceptance, order_id, kiz, is_b2b, trbx_id,
                installment_cofinancing_amount, wibes_discount_percent,
                cashback_amount, cashback_discount, cashback_commission_change,
                payment_schedule, delivery_method, seller_promo_id,
                seller_promo_discount, loyalty_id, loyalty_discount,
                uuid_promocode, sale_price_promocode_discount_prc,
                article_substitution, sale_price_affiliated_discount_prc,
                agency_vat, sale_price_wholesale_discount_prc, order_uid,
                srid
            ) VALUES (
                p_user_id, v_detail.report_id, v_detail.rrd_id,
                v_detail.date_from, v_detail.date_to, v_detail.create_date,
                COALESCE(v_detail.currency, 'RUB'), v_detail.report_type,
                v_detail.gi_id, v_detail.dlv_prc, v_detail.fix_tariff_date_from,
                v_detail.fix_tariff_date_to, v_detail.subject_name, v_detail.nm_id,
                v_detail.brand_name, v_detail.vendor_code, v_detail.tech_size,
                v_detail.sku, v_detail.doc_type_name, COALESCE(v_detail.quantity, 0),
                v_detail.retail_price, v_detail.retail_amount, v_detail.sale_percent,
                v_detail.commission_percent, v_detail.office_name,
                v_detail.seller_oper_name, v_detail.order_dt, v_detail.sale_dt,
                v_detail.rr_date, v_detail.shk_id, v_detail.retail_price_with_disc,
                v_detail.delivery_amount, v_detail.return_amount,
                v_detail.delivery_service, v_detail.gi_box_type_name,
                v_detail.product_discount_for_report, v_detail.seller_promo,
                v_detail.spp, v_detail.kvw_base, v_detail.kvw, v_detail.sup_rating_up,
                v_detail.is_kgvp_v2, v_detail.ppvz_sales_commission,
                v_detail.for_pay, v_detail.ppvz_reward, v_detail.acquiring_fee,
                v_detail.acquiring_percent, v_detail.payment_processing,
                v_detail.acquiring_bank, v_detail.vw, v_detail.vw_nds,
                v_detail.ppvz_office_name, v_detail.ppvz_office_id,
                v_detail.ppvz_supplier_name, v_detail.ppvz_supplier_inn,
                v_detail.declaration_number, v_detail.bonus_type_name,
                v_detail.sticker_id, v_detail.country, COALESCE(v_detail.srv_dbs, FALSE),
                v_detail.penalty, v_detail.additional_payment,
                v_detail.rebill_logistic_cost, v_detail.rebill_logistic_org,
                v_detail.paid_storage, v_detail.deduction, v_detail.paid_acceptance,
                v_detail.order_id, v_detail.kiz, COALESCE(v_detail.is_b2b, FALSE),
                v_detail.trbx_id, v_detail.installment_cofinancing_amount,
                v_detail.wibes_discount_percent, v_detail.cashback_amount,
                v_detail.cashback_discount, v_detail.cashback_commission_change,
                v_detail.payment_schedule, v_detail.delivery_method,
                v_detail.seller_promo_id, v_detail.seller_promo_discount,
                v_detail.loyalty_id, v_detail.loyalty_discount,
                v_detail.uuid_promocode, v_detail.sale_price_promocode_discount_prc,
                v_detail.article_substitution, v_detail.sale_price_affiliated_discount_prc,
                v_detail.agency_vat, v_detail.sale_price_wholesale_discount_prc,
                v_detail.order_uid, v_detail.srid
            )
            ON CONFLICT (user_id, report_id, rrd_id) DO NOTHING;
            
            IF FOUND THEN
                v_inserted := v_inserted + 1;
            ELSE
                v_skipped := v_skipped + 1;
            END IF;
            
        EXCEPTION WHEN OTHERS THEN
            v_errors := v_errors + 1;
            v_error_details := v_error_details || E'\n' || 
                'rrd_id=' || v_rrd_id || ': ' || SQLERRM || ' (State: ' || SQLSTATE || ')';
            RAISE NOTICE 'ERROR: rrd_id=%, error=%, state=%', 
                v_rrd_id, SQLERRM, SQLSTATE;
        END;
    END LOOP;
    
    RETURN QUERY SELECT v_processed, v_inserted, v_skipped, v_errors, v_error_details;
END;
$$;

COMMIT;

-- Rollback:
-- BEGIN;
-- DROP FUNCTION IF EXISTS get_campaign_assignable_cards(INTEGER);
-- DROP FUNCTION IF EXISTS add_group_cards_to_campaign(INTEGER, INTEGER);
-- DROP FUNCTION IF EXISTS sync_wb_fi_report_details(INTEGER, JSONB);
-- DROP VIEW IF EXISTS product_data CASCADE;
-- -- Recreate with old nmid...
-- COMMIT;