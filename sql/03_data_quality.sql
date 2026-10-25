-- understanding the tables & columns in the schema;
SELECT
    table_name,
    column_name,
    data_type
FROM information_schema.columns
WHERE table_schema = 'public'
ORDER BY table_name, ordinal_position;

-- understanding nulls across different tables;
SELECT
    'customers' AS table_name,
    'gender' AS column_name,
    COUNT(*) AS total_rows,
    COUNT(*) - COUNT(gender) AS null_count,
    (COUNT(*) - COUNT(gender)) * 100.0 / COUNT(*) AS null_percentage
FROM customers;

-- formulating a SQL query for calculating nulls across all tables and columns in the schema;
SELECT
    format(
        'SELECT %L AS table_name, %L AS column_name, COUNT(*) AS total_rows, COUNT(*) - COUNT(%I) AS null_count FROM %I;',
        table_name,
        column_name,
        column_name,
        table_name
    ) AS generated_sql
FROM information_schema.columns
WHERE table_schema = 'public';

CREATE TEMP TABLE null_profile (
    table_name TEXT,
    column_name TEXT,
    total_rows BIGINT,
    null_count BIGINT,
    null_percentage NUMERIC
);

-- using function for calculating and displaying nulls across all tables and columns in the schema in a temp table;
DO $$
DECLARE
    col RECORD;
BEGIN

    FOR col IN
        SELECT
            table_name,
            column_name
        FROM information_schema.columns
        WHERE table_schema = 'public'
    LOOP

        EXECUTE format(
            'INSERT INTO null_profile
             SELECT %L, %L,
                    COUNT(*),
                    COUNT(*) - COUNT(%I),
                    (COUNT(*) - COUNT(%I)) * 100.0 / COUNT(*)
             FROM %I',
             col.table_name,
             col.column_name,
             col.column_name,
             col.column_name,
             col.table_name
        );

    END LOOP;

END $$;

-- null checking;
SELECT *
FROM null_profile
ORDER BY table_name, null_percentage DESC;

-- filetring nulls across all the tables;
SELECT *
FROM null_profile
WHERE null_count > 0
ORDER BY null_percentage DESC;

-- understanding failure_reason cases/column;
SELECT
    payment_status,
    case when failure_reason is null then 'NULL' else 'NOT NULL' end as failure_reason_status,
    count(*) as payment_cnt
from
    payments
group by
    1, 2;

-- identifying duplicates in the multiple tables; (also uniqueness of Primary Key)
select
    campaign_id,
    count(*) as cnt
from
    marketing_campaigns
group by
    campaign_id
having
    count(*) > 1;

-- checking PRIMARY KEY Integrity;
select
    count(*) as cnt
from
    marketing_campaigns
where
    campaign_id is null;

-- Foreign key Integrity; (using JOINS)
select
    count(*) as orphan_records
from
    events e
left join
    products p
on
    e.product_id = p.product_id
where
    e.product_id is not null
and
    p.product_id is null;

-- Invalid Numeric Values;
SELECT
    CASE
        WHEN EXTRACT(EPOCH FROM (e.event_timestamp - s.session_end)) <= 60
            THEN '0-1 min'
        WHEN EXTRACT(EPOCH FROM (e.event_timestamp - s.session_end)) <= 300
            THEN '1-5 min'
        WHEN EXTRACT(EPOCH FROM (e.event_timestamp - s.session_end)) <= 600
            THEN '5-10 min'
        ELSE '>10 min'
    END AS gap_bucket,
    COUNT(*) AS event_count
FROM events e
JOIN sessions s
    ON e.session_id = s.session_id
WHERE s.session_end IS NOT NULL
  AND e.event_timestamp > s.session_end
GROUP BY
    CASE
        WHEN EXTRACT(EPOCH FROM (e.event_timestamp - s.session_end)) <= 60
            THEN '0-1 min'
        WHEN EXTRACT(EPOCH FROM (e.event_timestamp - s.session_end)) <= 300
            THEN '1-5 min'
        WHEN EXTRACT(EPOCH FROM (e.event_timestamp - s.session_end)) <= 600
            THEN '5-10 min'
        ELSE '>10 min'
    END
ORDER BY
    MIN(e.event_timestamp - s.session_end);

-- Order & Payment Consistency;
SELECT
    o.order_status,
    COUNT(*) AS underpaid_orders,
    ROUND(SUM(o.order_total - x.paid_amount), 2) AS total_shortfall,
    ROUND(AVG(o.order_total - x.paid_amount), 2) AS avg_shortfall
FROM orders o
JOIN (
    SELECT
        order_id,
        SUM(
            CASE
                WHEN payment_status = 'Paid'
                THEN amount
                ELSE 0
            END
        ) AS paid_amount
    FROM payments
    GROUP BY order_id
) x
    ON o.order_id = x.order_id
WHERE x.paid_amount < o.order_total
GROUP BY o.order_status
ORDER BY total_shortfall DESC;

-- Order & Return Consistency;
SELECT
    COUNT(*) AS suspicious_returns,
    ROUND(SUM(r.refund_amount), 2) AS total_refund_amount,
    ROUND(SUM(oi.item_total), 2) AS total_item_value
FROM returns r
JOIN order_items oi
    ON r.order_item_id = oi.order_item_id
WHERE r.refund_amount > oi.item_total;

--- refund excess per return
SELECT
    COUNT(*) AS suspicious_returns,
    ROUND(
        SUM(r.refund_amount - oi.item_total),
        2
    ) AS total_excess_refund,
    ROUND(
        AVG(r.refund_amount - oi.item_total),
        2
    ) AS avg_excess_refund,
    ROUND(
        MAX(r.refund_amount - oi.item_total),
        2
    ) AS max_excess_refund
FROM returns r
JOIN order_items oi
    ON r.order_item_id = oi.order_item_id
WHERE r.refund_amount > oi.item_total;

-- Margin Anomalies/Product Pricing;
SELECT
    COUNT(*) AS invalid_products,
    ROUND(SUM(cost_price - unit_price), 2) AS total_negative_margin,
    ROUND(AVG(cost_price - unit_price), 2) AS avg_negative_margin,
    ROUND(MAX(cost_price - unit_price), 2) AS max_negative_margin
FROM products
WHERE cost_price > unit_price;

-- Marketing Budget Anomalies;
SELECT
    COUNT(*) AS over_budget_campaigns,
    ROUND(SUM(campaign_spend - campaign_budget), 2) AS total_budget_overrun,
    ROUND(AVG(campaign_spend - campaign_budget), 2) AS avg_budget_overrun,
    ROUND(MAX(campaign_spend - campaign_budget), 2) AS max_budget_overrun
FROM marketing_campaigns
WHERE campaign_spend > campaign_budget;

