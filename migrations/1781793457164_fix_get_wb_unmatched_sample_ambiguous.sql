-- ============================================================================
-- Migration: fix_get_wb_unmatched_sample_ambiguous
-- Description: Fix ambiguous column references
-- ============================================================================

BEGIN;

DROP FUNCTION IF EXISTS get_wb_unmatched_sample(INTEGER, BIGINT, INTEGER);

CREATE OR REPLACE FUNCTION get_wb_unmatched_sample(
    p_user_id INTEGER,
    p_report_id BIGINT,
    p_limit INTEGER DEFAULT 10
)
RETURNS JSONB LANGUAGE sql AS $$
    SELECT COALESCE(
        jsonb_agg(
            jsonb_build_object(
                'rrd_id', (u.row_data->>'rrd_id')::BIGINT,
                'doc_type_name', u.row_data->>'doc_type_name',
                'seller_oper_name', u.row_data->>'seller_oper_name',
                'bonus_type_name', u.row_data->>'bonus_type_name',
                'for_pay', u.row_data->>'for_pay',
                'delivery_service', u.row_data->>'delivery_service',
                'penalty', u.row_data->>'penalty',
                'retail_amount', u.row_data->>'retail_amount',
                'paid_storage', u.row_data->>'paid_storage',
                'additional_payment', u.row_data->>'additional_payment',
                'agency_vat', u.row_data->>'agency_vat'
            )
            ORDER BY (u.row_data->>'rrd_id')::BIGINT
        ),
        '[]'::JSONB
    )
    FROM (
        SELECT *
        FROM wb_fi_unmatched_rows
        WHERE user_id = p_user_id 
          AND report_id = p_report_id
        ORDER BY (row_data->>'rrd_id')::BIGINT
        LIMIT p_limit
    ) u;
$$;

COMMENT ON FUNCTION get_wb_unmatched_sample(INTEGER, BIGINT, INTEGER) IS 
'Returns unmatched rows sample. LIMIT applied BEFORE aggregation.';

COMMIT;