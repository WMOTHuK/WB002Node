DROP FUNCTION IF EXISTS get_overheads_4months(INTEGER, DATE);

CREATE OR REPLACE FUNCTION get_overheads_4months(
    p_user_id INTEGER,
    p_month DATE DEFAULT CURRENT_DATE
)
RETURNS TABLE (
    oh_month VARCHAR(10),
    ohcat_id INTEGER,
    ohcat_name VARCHAR(255),
    oh_grp_id INTEGER,
    platform VARCHAR(10),
    oh_amount NUMERIC(12,2)
) LANGUAGE sql STABLE AS $$
    SELECT 
        TO_CHAR(m.month, 'YYYY-MM-DD')::VARCHAR(10),
        c.id,
        c.name_ru,
        c.oh_grp_id,
        p.platform,
        COALESCE(o.amount, 0)::NUMERIC(12,2)
    FROM generate_series(
        date_trunc('month', COALESCE(p_month, CURRENT_DATE))::DATE - INTERVAL '1 month',
        date_trunc('month', COALESCE(p_month, CURRENT_DATE))::DATE + INTERVAL '2 months',
        '1 month'
    ) AS m(month)
    CROSS JOIN fi_ohcat_active_multilang c
    CROSS JOIN (VALUES ('wb'), ('ozon')) AS p(platform)
    LEFT JOIN fi_overheads o ON 
        o.user_id = p_user_id
        AND o.month = m.month
        AND o.ohcat_id = c.id
        AND o.platform = p.platform
    ORDER BY m.month, p.platform, c.id;
$$;