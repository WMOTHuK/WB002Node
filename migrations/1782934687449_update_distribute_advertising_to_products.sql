-- ============================================================================
-- Migration: update_distribute_advertising_to_products
-- Description: Use updated get_advertising_expenses
-- ============================================================================

BEGIN;

DROP FUNCTION IF EXISTS distribute_advertising_to_products(INTEGER, BIGINT, BIGINT[]);

CREATE OR REPLACE FUNCTION distribute_advertising_to_products(
    p_user_id INTEGER,
    p_report_id BIGINT,
    p_report_ids BIGINT[]
)
RETURNS VOID LANGUAGE plpgsql AS $$
DECLARE
    v_advert RECORD;
    v_product RECORD;
    v_total_quantity NUMERIC(15,3);
    v_share NUMERIC(15,6);
    v_amount_per_product NUMERIC(15,2);
    v_campaign_products_count INTEGER;
BEGIN
    -- Clear existing advertising in product summary
    UPDATE wb_fi_report_product_summary
    SET advertising = 0
    WHERE user_id = p_user_id AND report_id = p_report_id;
    
    -- Loop through each advert_id with expenses
    FOR v_advert IN 
        SELECT advert_id, total_amount
        FROM get_advertising_expenses(p_user_id, p_report_ids)
    LOOP
        -- Check if advert has products in campaign_subcards
        IF NOT EXISTS (
            SELECT 1 FROM crm_campaign_subcards 
            WHERE advert_id = v_advert.advert_id
        ) THEN
            CONTINUE;
        END IF;
        
        -- Get products with sales for this advert_id (via vendorcode -> goods -> nm_id)
        SELECT 
            COALESCE(SUM(ps.quantity), 0) INTO v_total_quantity
        FROM crm_campaign_subcards cs
        JOIN goods g ON g.vendorcode = cs.vendorcode
        JOIN wb_fi_report_product_summary ps ON ps.nm_id = g.nm_id
        WHERE cs.advert_id = v_advert.advert_id
          AND ps.user_id = p_user_id 
          AND ps.report_id = p_report_id
          AND ps.quantity > 0;
        
        -- Get total products in campaign (for equal distribution)
        SELECT COUNT(*) INTO v_campaign_products_count
        FROM crm_campaign_subcards cs
        WHERE cs.advert_id = v_advert.advert_id;
        
        -- If there are products with sales, distribute proportionally by quantity
        IF v_total_quantity > 0 THEN
            -- Distribute by quantity
            FOR v_product IN
                SELECT 
                    g.nm_id,
                    ps.quantity
                FROM crm_campaign_subcards cs
                JOIN goods g ON g.vendorcode = cs.vendorcode
                JOIN wb_fi_report_product_summary ps ON ps.nm_id = g.nm_id
                WHERE cs.advert_id = v_advert.advert_id
                  AND ps.user_id = p_user_id 
                  AND ps.report_id = p_report_id
                  AND ps.quantity > 0
            LOOP
                v_share := v_product.quantity / v_total_quantity;
                v_amount_per_product := ROUND(v_advert.total_amount * v_share, 2);
                
                UPDATE wb_fi_report_product_summary
                SET advertising = COALESCE(advertising, 0) + v_amount_per_product
                WHERE user_id = p_user_id 
                  AND report_id = p_report_id 
                  AND nm_id = v_product.nm_id;
            END LOOP;
            
        -- If no products with sales but campaign has products, distribute equally
        ELSIF v_campaign_products_count > 0 THEN
            -- Distribute equally among all products in campaign
            v_amount_per_product := ROUND(v_advert.total_amount / v_campaign_products_count, 2);
            
            FOR v_product IN
                SELECT 
                    g.nm_id
                FROM crm_campaign_subcards cs
                JOIN goods g ON g.vendorcode = cs.vendorcode
                WHERE cs.advert_id = v_advert.advert_id
            LOOP
                UPDATE wb_fi_report_product_summary
                SET advertising = COALESCE(advertising, 0) + v_amount_per_product
                WHERE user_id = p_user_id 
                  AND report_id = p_report_id 
                  AND nm_id = v_product.nm_id;
            END LOOP;
        END IF;
    END LOOP;
    
    -- НЕ перезаписываем summary advertising!
END;
$$;

COMMENT ON FUNCTION distribute_advertising_to_products(INTEGER, BIGINT, BIGINT[]) IS 
'Distribute advertising costs to products. Does NOT update summary advertising.';

COMMIT;