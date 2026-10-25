Phase 1 — Data Quality & Validation
Objective:
Validate whether the NovaCart e-commerce database is structurally reliable and identify business/data inconsistencies before performing customer, product, revenue, funnel, and retention analytics.

Tables validated
customers
products
orders
order_items
payments
returns
sessions
events
marketing_campaigns

1. NULL / Missing-Value Profiling
Logic
Instead of manually checking every column, we dynamically inspected every column in every public table.

Step 1 — Temporary profiling table
CREATE TEMP TABLE null_profile (
    table_name TEXT,
    column_name TEXT,
    total_rows BIGINT,
    null_count BIGINT,
    null_percentage NUMERIC
);
Step 2 — Dynamically profile every column
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
Key findings
Table	Column	NULL %	Interpretation
payments	failure_reason	94.04%	Expected — paid payments have no failure reason
events	product_id	40.57%	Expected for non-product events
sessions	customer_id	25.00%	Anonymous sessions
events	customer_id	24.97%	Anonymous activity
customers	gender	7.75%	Missing demographic information
customers	city	5.97%	Missing location information
Conditional validation

We specifically tested whether failure_reason behaved logically:

SELECT
    payment_status,
    CASE
        WHEN failure_reason IS NULL THEN 'NULL'
        ELSE 'NOT NULL'
    END AS failure_reason_status,
    COUNT(*) AS payment_count
FROM payments
GROUP BY payment_status, failure_reason_status
ORDER BY payment_status, failure_reason_status;

Result:

Failed → reason present
Paid → reason NULL

Conclusion: ✅ Expected NULL pattern

Key learning:
A NULL is not automatically a data-quality problem. You need to determine whether NULL is semantically valid.

2. Duplicate Records
We checked duplicate primary identifiers across all nine tables.

Logic
SELECT
    customer_id,
    COUNT(*)
FROM customers
GROUP BY customer_id
HAVING COUNT(*) > 1;

The same pattern was applied to:

products.product_id
orders.order_id
order_items.order_item_id
payments.payment_id
returns.return_id
sessions.session_id
events.event_id
marketing_campaigns.campaign_id

No duplicate primary keys were found.

Conclusion: ✅ PASS

3. Primary-Key Integrity
Logic
Check whether any primary key is NULL.

Example:

SELECT COUNT(*) AS null_primary_keys
FROM customers
WHERE customer_id IS NULL;

Repeated for every table.

All returned:

0

Conclusion: ✅ PASS

Why this matters

A primary key must uniquely identify a record and cannot be missing. Without this, joins and aggregations become unreliable.

4. Foreign-Key Integrity
We checked whether child records referenced nonexistent parent records.

Example
SELECT COUNT(*) AS orphan_orders
FROM orders o
LEFT JOIN customers c
    ON o.customer_id = c.customer_id
WHERE o.customer_id IS NOT NULL
  AND c.customer_id IS NULL;

Applied to:

orders → customers
order_items → orders
order_items → products
payments → orders
returns → order_items
sessions → customers
events → sessions
events → customers
events → products

All returned 0 orphan records.

Conclusion: ✅ PASS

Important logic

For nullable foreign keys such as sessions.customer_id, we don't treat NULL as an orphan.

We specifically use:

WHERE s.customer_id IS NOT NULL
  AND c.customer_id IS NULL

That's an important SQL/data-quality distinction.

5. Invalid Numeric Values
We checked whether numerical fields contained logically impossible values.

Checks performed
Orders
WHERE order_total < 0
WHERE discount_amount < 0
WHERE shipping_fee < 0
Order items
WHERE quantity <= 0
WHERE item_total <= 0
Products
WHERE cost_price > unit_price
Payments
WHERE amount <= 0
Returns
WHERE refund_amount <= 0

And:

WHERE quantity_returned > quantity
Findings

No material invalid numeric records were identified.

Conclusion: ✅ PASS

6. Date & Timestamp Anomalies
This was one of the more important sections because temporal relationships matter heavily in an e-commerce system.

6.1 Order before customer signup
Logic
SELECT COUNT(*) AS invalid_orders
FROM orders o
JOIN customers c
    ON o.customer_id = c.customer_id
WHERE o.order_timestamp < c.signup_date;

Result:

0

Conclusion: ✅ PASS

6.2 Payment before order
Logic
SELECT COUNT(*) AS invalid_payments
FROM payments p
JOIN orders o
    ON p.order_id = o.order_id
WHERE p.payment_timestamp < o.order_timestamp;

This checks whether payment timestamps precede the corresponding order.

6.3 Return before order
Logic
SELECT COUNT(*) AS invalid_returns
FROM returns r
JOIN order_items oi
    ON r.order_item_id = oi.order_item_id
JOIN orders o
    ON oi.order_id = o.order_id
WHERE r.return_date < o.order_timestamp;

This validates the sequence:

Order → Return

6.4 Order before product launch

This produced an important finding.

SELECT COUNT(*) AS invalid_order_items
FROM orders o
JOIN order_items oi
    ON o.order_id = oi.order_id
JOIN products p
    ON oi.product_id = p.product_id
WHERE o.order_timestamp::DATE < p.launch_date;

Result:

27,043

Percentage
SELECT
    COUNT(*) AS invalid_order_items,
    ROUND(
        COUNT(*) * 100.0 /
        (SELECT COUNT(*) FROM order_items),
        2
    ) AS invalid_percentage
FROM orders o
JOIN order_items oi
    ON o.order_id = oi.order_id
JOIN products p
    ON oi.product_id = p.product_id
WHERE o.order_timestamp::DATE < p.launch_date;

Result:

7.02%

Further investigation

We checked affected categories:

Electronics — 5,335
Fashion — 5,192
Home & Kitchen — 4,504
Sports — 4,335
Grocery — 4,150
Beauty — 3,527

566 products were affected.

We also calculated the gap between launch and order:

Minimum: 1 day
Maximum: 533 days
Average: 126.62 days
Conclusion

⚠️ INVESTIGATE

This is clearly systematic rather than a tiny timestamp-rounding issue.

Possible explanation: launch_date may represent a later launch/relaunch date rather than the product's original availability date.

6.5 Session end before session start
SELECT COUNT(*) AS invalid_sessions
FROM sessions
WHERE session_end IS NOT NULL
  AND session_end < session_start;

This checks:

session_start ≤ session_end

6.6 Event before session start
SELECT COUNT(*) AS invalid_events
FROM events e
JOIN sessions s
    ON e.session_id = s.session_id
WHERE e.event_timestamp < s.session_start;

This checks:

session_start ≤ event_timestamp

6.7 Event after session end
SELECT COUNT(*) AS invalid_events
FROM events e
JOIN sessions s
    ON e.session_id = s.session_id
WHERE s.session_end IS NOT NULL
  AND e.event_timestamp > s.session_end;

Result:

493,968 events

Percentage

33.4%

We then investigated the time difference:

Gap	Events
0–1 min	188,978
1–5 min	248,534
5–10 min	56,454
>10 min	2

Average gap:

2.23 minutes

Conclusion

⚠️ INVESTIGATE / ACCEPTABLE WITH CAVEAT

The volume looks large, but the magnitude is small. Almost all anomalies occur within a few minutes.

Likely explanation: session termination/timeout logic rather than severe timestamp corruption.

7. Order & Payment Consistency
This became the most important Phase 1 finding.

7.1 Orders with payments
SELECT
    o.order_status,
    COUNT(*) AS order_count,
    COUNT(p.payment_id) AS orders_with_payment
FROM orders o
LEFT JOIN payments p
    ON o.order_id = p.order_id
GROUP BY o.order_status
ORDER BY order_count DESC;

All orders had associated payment records.

7.2 Order status vs payment status
SELECT
    o.order_status,
    p.payment_status,
    COUNT(*) AS order_payment_count
FROM orders o
JOIN payments p
    ON o.order_id = p.order_id
GROUP BY o.order_status, p.payment_status
ORDER BY o.order_status, p.payment_status;

Results included:

Completed / Paid: 165,339
Completed / Failed: 10,493
Cancelled / Paid: 15,175
Cancelled / Failed: 999
Pending / Paid: 9,575
Pending / Failed: 562

This showed that payment and order states don't always align cleanly.

7.3 Multiple payment attempts
SELECT
    o.order_status,
    COUNT(DISTINCT o.order_id) AS orders,
    COUNT(p.payment_id) AS payment_attempts
FROM orders o
JOIN payments p
    ON o.order_id = p.order_id
GROUP BY o.order_status
ORDER BY o.order_status;

This identified orders having multiple payment attempts.

That's realistic in an e-commerce environment because a customer can retry a failed payment.

7.4 Completed orders with only failed payments

This was particularly concerning.

SELECT
    COUNT(*) AS completed_orders_with_only_failed_payments
FROM (
    SELECT
        o.order_id
    FROM orders o
    JOIN payments p
        ON o.order_id = p.order_id
    WHERE o.order_status = 'Completed'
    GROUP BY o.order_id
    HAVING COUNT(*) FILTER (
        WHERE p.payment_status = 'Paid'
    ) = 0
) x;

Result:

8,614 completed orders

These represent approximately 4.9% of completed orders.

Conclusion

🔴 Critical anomaly

A completed order with no successful payment requires investigation.

8. Payment Amount vs Order Total
We then tested whether successful payment amounts actually covered the order value.

Logic
SELECT
    COUNT(*) AS mismatched_orders
FROM (
    SELECT
        o.order_id,
        o.order_total,
        SUM(
            CASE
                WHEN p.payment_status = 'Paid'
                THEN p.amount
                ELSE 0
            END
        ) AS paid_amount
    FROM orders o
    JOIN payments p
        ON o.order_id = p.order_id
    GROUP BY
        o.order_id,
        o.order_total
) x
WHERE ROUND(paid_amount, 2) <> ROUND(order_total, 2);

Result:

9,911 mismatched orders

Direction of mismatch
Exact: 190,089
Underpaid: 9,911
Overpaid: 0

Total shortfall:

$1,885,028.46

Average shortfall:

$190.20

Maximum:

$2,702.22

Segmenting the shortfall
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

Result:

Order status	Underpaid orders	Shortfall
Completed	8,614	$1,641,007.25
Cancelled	842	$161,616.24
Pending	455	$82,404.97
Business conclusion

The completed-order shortfall of $1.641M is the most important financial integrity finding in Phase 1.

9. Order & Return Consistency
We had already checked:

WHERE r.quantity_returned > oi.quantity

Result:

0

So customers aren't returning more units than they originally purchased.

Then we checked refund value.

SELECT
    COUNT(*) AS suspicious_returns,
    ROUND(SUM(r.refund_amount), 2) AS total_refund_amount,
    ROUND(SUM(oi.item_total), 2) AS total_item_value
FROM returns r
JOIN order_items oi
    ON r.order_item_id = oi.order_item_id
WHERE r.refund_amount > oi.item_total;

Result:

Suspicious returns: 10,120
Refund amount: $919,072.00
Item value: $835,372.41

Then:

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

Result:

10,120 suspicious returns
$83,699.59 total excess
$8.27 average excess
$313.95 maximum excess
Conclusion

⚠️ INVESTIGATE

Important caveat: refund_amount could theoretically include refunded shipping/tax/etc., but our current schema doesn't separately model those components.

10. Product Pricing / Margin
We tested whether any product has:

cost_price > unit_price

Query:

SELECT
    COUNT(*) AS invalid_products,
    ROUND(SUM(cost_price - unit_price), 2) AS total_negative_margin,
    ROUND(AVG(cost_price - unit_price), 2) AS avg_negative_margin,
    ROUND(MAX(cost_price - unit_price), 2) AS max_negative_margin
FROM products
WHERE cost_price > unit_price;

Result:

0 | NULL | NULL | NULL

The NULLs are expected because there are no qualifying records.

Conclusion

✅ PASS

No products have a negative theoretical gross margin.

11. Marketing Budget Anomalies
Finally, we checked whether campaign spend exceeded allocated budget.

SELECT
    COUNT(*) AS over_budget_campaigns,
    ROUND(SUM(campaign_spend - campaign_budget), 2) AS total_budget_overrun,
    ROUND(AVG(campaign_spend - campaign_budget), 2) AS avg_budget_overrun,
    ROUND(MAX(campaign_spend - campaign_budget), 2) AS max_budget_overrun
FROM marketing_campaigns
WHERE campaign_spend > campaign_budget;

Result:

Metric	Result
Over-budget campaigns	12
Total overrun	$16,510.37
Average overrun	$1,375.86
Maximum overrun	$3,937.88
Conclusion

⚠️ INVESTIGATE

Phase 1 Final Scorecard
Area	Status	Key Finding
NULL profiling	⚠️	Mostly legitimate/expected NULLs
Duplicates	✅	No duplicate PKs
Primary keys	✅	No NULL PKs
Foreign keys	✅	No orphan records
Numeric integrity	✅	No major invalid values
Date integrity	⚠️	Product-launch anomaly
Session/event timing	⚠️	33.4% events after session end, mostly within 5 min
Payment integrity	🔴	8,614 completed orders without successful payment
Payment amounts	🔴	$1.885M total shortfall
Return integrity	⚠️	$83.7K unexplained excess refunds
Product pricing	✅	No negative-margin products
Marketing budget	⚠️	$16.5K campaign overrun
The three biggest business findings

1. Payment integrity — 🔴 Highest priority
8,614 completed orders appear to lack a successful payment, with $1.641M of shortfall among completed orders.

2. Return/refund integrity — ⚠️
10,120 returns exceed their recorded item value, representing $83.7K of excess refund value.

3. Product/timestamp integrity — ⚠️
27,043 order items (7.02%) appear to have been purchased before their recorded product launch date.