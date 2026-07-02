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
    v_error_message TEXT;
    v_sum_distributed NUMERIC(15,2);
    v_diff NUMERIC(15,2);
    v_max_quantity_nm_id BIGINT;
    v_max_quantity NUMERIC(15,3);
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
        SELECT COUNT(*) INTO v_campaign_products_count
        FROM crm_campaign_subcards 
        WHERE advert_id = v_advert.advert_id;
        
        -- If no products in campaign, raise error
        IF v_campaign_products_count = 0 THEN
            v_error_message := FORMAT(
                'Campaign %s has no products in crm_campaign_subcards. Cannot distribute advertising costs.',
                v_advert.advert_id
            );
            RAISE EXCEPTION '%', v_error_message;
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
        
        -- Reset sum for this campaign
        v_sum_distributed := 0;
        v_max_quantity := 0;
        v_max_quantity_nm_id := NULL;
        
        -- If there are products with sales, distribute proportionally by quantity
        IF v_total_quantity > 0 THEN
            -- First pass: calculate and store amounts, track max quantity
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
                -- Track product with max quantity
                IF v_product.quantity > v_max_quantity THEN
                    v_max_quantity := v_product.quantity;
                    v_max_quantity_nm_id := v_product.nm_id;
                END IF;
                
                v_share := v_product.quantity / v_total_quantity;
                v_amount_per_product := ROUND(v_advert.total_amount * v_share, 2);
                v_sum_distributed := v_sum_distributed + v_amount_per_product;
                
                UPDATE wb_fi_report_product_summary
                SET advertising = COALESCE(advertising, 0) + v_amount_per_product
                WHERE user_id = p_user_id 
                  AND report_id = p_report_id 
                  AND nm_id = v_product.nm_id;
            END LOOP;
            
        -- If no products with sales but campaign has products, distribute equally
        ELSIF v_campaign_products_count > 0 THEN
            -- First pass: calculate and store amounts
            FOR v_product IN
                SELECT 
                    g.nm_id
                FROM crm_campaign_subcards cs
                JOIN goods g ON g.vendorcode = cs.vendorcode
                WHERE cs.advert_id = v_advert.advert_id
            LOOP
                -- Track product (all have equal quantity in this case)
                IF v_max_quantity_nm_id IS NULL THEN
                    v_max_quantity_nm_id := v_product.nm_id;
                END IF;
                
                v_amount_per_product := ROUND(v_advert.total_amount / v_campaign_products_count, 2);
                v_sum_distributed := v_sum_distributed + v_amount_per_product;
                
                UPDATE wb_fi_report_product_summary
                SET advertising = COALESCE(advertising, 0) + v_amount_per_product
                WHERE user_id = p_user_id 
                  AND report_id = p_report_id 
                  AND nm_id = v_product.nm_id;
            END LOOP;
        END IF;
        
        -- Apply rounding correction if needed
        v_diff := v_advert.total_amount - v_sum_distributed;
        
        -- If diff exists and is less than 1 ruble, add it to the product with max quantity
        IF ABS(v_diff) > 0 AND ABS(v_diff) < 1 AND v_max_quantity_nm_id IS NOT NULL THEN
            UPDATE wb_fi_report_product_summary
            SET advertising = advertising + v_diff
            WHERE user_id = p_user_id 
              AND report_id = p_report_id 
              AND nm_id = v_max_quantity_nm_id;
        END IF;
    END LOOP;
    
    -- НЕ перезаписываем summary advertising!
END;
$$;

COMMENT ON FUNCTION distribute_advertising_to_products(INTEGER, BIGINT, BIGINT[]) IS 
'Distribute advertising costs to products with rounding correction.';

COMMIT;