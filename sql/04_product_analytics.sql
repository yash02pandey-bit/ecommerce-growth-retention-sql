-- How large is NovaCart's customer base across customer status and acquisition channel?
select
    count(*) as cust_count,
    customer_status,
    acquisition_channel
from
    customers
group by
    customer_status,
    acquisition_channel
order by
    customer_status,
    cust_count DESC;

-- Which acquisition channels have the largest customer base?
select
    acquisition_channel,
    count(*) as cust_count
from
    customers
group by
    acquisition_channel
order by
    cust_count desc
limit 1;

-- Customer Base Distribution
select
    acquisition_channel,
    count(*) as total_cust,
    round(count(*) * 100 / (select count(*) from customers),2) as cust_percent
from
    customers
group by
    acquisition_channel
order by
    cust_percent desc;

-- How many customers have never placed an order, and how many have placed at least one order?
select
    c.customer_status as customer_status,
    count(distinct case when o.customer_id is null then c.customer_id end) as never_purchased,
    count(distinct case when o.customer_id is not null then c.customer_id end) as purchased
from
    customers c
left join
    orders o
on
    c.customer_id = o.customer_id
group by
    c.customer_status
order by
    customer_status,
    never_purchased desc,
    purchased desc;

-- What percentage of customers have made at least one purchase?
select
    count(distinct c.customer_id) as total_customers,
    count(distinct case when o.customer_id is null then c.customer_id end) as non_purchasing_customers,
    count(distinct case when o.customer_id is not null then c.customer_id end) as purchasing_customers,
    round(((count(distinct case when o.customer_id is not null then c.customer_id end) * 100.0)/(select count(*) from customers)),2) as purchase_conversion_rate
from
    customers c
left join
    orders o
on
    c.customer_id = o.customer_id;

-- How many customers have purchased exactly once versus multiple times?
with purchasing as (
    select
        c.customer_id as customer_id,
        case when count(o.customer_id) = 1 then 'one_time_customer' when count(o.customer_id) > 1 then 'repeat_customer' end as purchase_segment
    from
        customers c
    join
        orders o
    on
        c.customer_id = o.customer_id
    group by
        c.customer_id
)
select
    purchase_segment,
    count(customer_id)
from
    purchasing
group by
    purchase_segment;

-- What percentage of customers who have made at least one purchase are repeat customers?

with pre_agg as (select
    a.customer_id,
    count(b.order_id) as orders_count
from
    customers a
left join
    orders b
ON
    a.customer_id = b.customer_id
group by
    a.customer_id)

select
    COUNT(CASE WHEN orders_count >= 1 THEN 1 END) AS total_purchasing_customers,
    count(case when orders_count > 1 then customer_id end) as repeat_customers,
    ROUND(COUNT(CASE WHEN orders_count > 1 THEN 1 END) * 100.0 / NULLIF(COUNT(CASE WHEN orders_count >= 1 THEN 1 END), 0), 2) AS repeat_purchase_rate
from
    pre_agg;

-- On average, how many orders does each purchasing customer place?

with pre_avg as (select
    a.customer_id,
    count(b.order_id) as order_counts
from
    customers a
left join
    orders b
on
    a.customer_id = b.customer_id
where
    b.order_status = 'Completed'
group by
    a.customer_id)

select
    count(distinct customer_id) as total_purchasing_customers,
    sum(order_counts) as total_orders,
    round(avg(order_counts), 0) as avg_orders
from
    pre_avg;

-- How much revenue has each customer generated from their completed orders?

select
    a.customer_id,
    count(distinct b.order_id) as total_orders,
    sum(b.order_total) as total_revenue
from
    customers a
left join
    orders b
on
    a.customer_id = b.customer_id
where
    b.order_status = 'Completed'
group by
    a.customer_id
order by
    total_revenue desc;

-- What is the average order value for each customer, based on their completed orders?
with pre_agg as (select
    a.customer_id,
    count(distinct b.order_id) as total_orders,
    sum(b.order_total) as total_revenue
from
    customers a
left join
    orders b
on
    a.customer_id = b.customer_id
where
    b.order_status = 'Completed'
group by
    a.customer_id
order by
    total_revenue desc)

select
    customer_id,
    total_orders,
    total_revenue,
    round((total_revenue) / total_orders, 2) as avg_order_val
from
    pre_agg
group by
    customer_id,
    total_orders,
    total_revenue;

-- Who are NovaCart's top 10 customers by completed-order revenue, and what is each customer's rank?
with pre_rank as (select
    a.customer_id,
    sum(b.order_total) as total_revenue
from
    customers a
left join
    orders b
on
    a.customer_id = b.customer_id
where
    b.order_status = 'Completed'
group by
    a.customer_id)

select
    customer_id,
    total_revenue,
    rank() over(order by total_revenue desc) as revenue_rank
from
    pre_rank
limit 10;

-- Which customer acquisition channels generate the highest completed-order revenue?

with pre_agg as(select
    a.acquisition_channel,
    count(distinct a.customer_id) as total_customers,
    count(distinct b.order_id) as total_orders,
    round(sum(b.order_total), 2) as total_revenue
from
    customers a
left join
    orders b
on
    a.customer_id = b.customer_id
and
    b.order_status = 'Completed'
group by
    a.acquisition_channel
order by
    total_revenue desc)

select
    *,
    ROUND(total_revenue / total_orders, 2) as avg_order_value
from
    pre_agg
limit 1;

-- For each customer who has placed at least one completed order, when did they make their first and most recent purchase?

with pre_ag as (select
    a.customer_id,
    max(b.order_timestamp) as first_purchase_date,
    min(b.order_timestamp) as last_purchase_date,
    count(distinct b.order_id) as total_orders,
    sum(b.order_total) as total_revenue
from
    customers a
left join
    orders b
on
    a.customer_id = b.customer_id
and
    b.order_status = 'Completed'
group by
    a.customer_id)

select
    *
from
    pre_ag
where
    total_orders >= 1;

-- How many days has it been since each purchasing customer's most recent completed order?
with pre_ag as (select
    a.customer_id,
    min(b.order_timestamp) as first_purchase_date,
    max(b.order_timestamp) as last_purchase_date,
    count(distinct b.order_id) as total_orders,
    sum(b.order_total) as total_revenue
from
    customers a
left join
    orders b
on
    a.customer_id = b.customer_id
and
    b.order_status = 'Completed'
group by
    a.customer_id)

select
    customer_id,
    CURRENT_DATE - last_purchase_date::DATE as days_since_last_purchase
from
    pre_ag
where
    total_orders >= 1;

-- Segment purchasing customers according to how recently they made their last completed purchase.
with pre_ag as (select
    a.customer_id,
    min(b.order_timestamp) as first_purchase_date,
    max(b.order_timestamp) as last_purchase_date,
    count(distinct b.order_id) as total_orders
from
    customers a
left join
    orders b
on
    a.customer_id = b.customer_id
and
    b.order_status = 'Completed'
group by
    a.customer_id),

segmenting as (select
    customer_id,
    CURRENT_DATE - last_purchase_date::DATE as days_since_last_purchase
from
    pre_ag
where
    total_orders >= 1)

select
    case when days_since_last_purchase between 0 and 30 then 'Recent'
    when days_since_last_purchase between 31 and 90 then 'Warm'
    when days_since_last_purchase > 90 then 'Dormant' end as customer_segment,
    count(*) as cust_count,
    ROUND(COUNT(*) * 100.0 / (SELECT COUNT(*) FROM segmenting),2) AS customer_percentage
from
    segmenting
group by
    case when days_since_last_purchase between 0 and 30 then 'Recent'
    when days_since_last_purchase between 31 and 90 then 'Warm'
    when days_since_last_purchase > 90 then 'Dormant' end;

-- Which customers belong to the top 10% of customers by total completed-order revenue?
with pre_agg as (select
    a.customer_id,
    sum(b.order_total) as total_revenue
from
    customers a
inner join
    orders b
on
    a.customer_id = b.customer_id
and
    b.order_status = 'Completed'
group by
    a.customer_id),
ranked as(select
    customer_id,
    total_revenue,
    ntile(10) over(order by total_revenue desc) as revenue_ntiles
from
    pre_agg)
select * from ranked where revenue_ntiles = 1;

-- Which acquisition channels bring in customers who are most likely to make repeat purchases?
select * from customers limit 3;
select * from orders limit 3;

with pre_agg as(select
    a.acquisition_channel,
    a.customer_id,
    count(b.order_id) as completed_customers
from
    customers a
left join
    orders b
on
    a.customer_id = b.customer_id
and
    b.order_status = 'Completed'
group by
    a.acquisition_channel,
    a.customer_id)
select
    acquisition_channel,
    count(case when completed_customers >= 1 then customer_id end) as purchasing_customers,
    count(case when completed_customers > 1 then customer_id end) as repeat_customers,
    count(case when completed_customers > 1 then customer_id end) * 100 / count(case when completed_customers >= 1 then customer_id end) as repeat_rate
from
    pre_agg
group by
    acquisition_channel;

-- What is the average revenue generated per purchasing customer across each acquisition channel?
with pre_agg as(select
    a.acquisition_channel,
    a.customer_id,
    count(b.order_id) as completed_orders,
    sum(b.order_total) as total_revenue
from
    customers a
left join
    orders b
on
    a.customer_id = b.customer_id
and
    b.order_status = 'Completed'
group by
    a.acquisition_channel,
    a.customer_id)

select
    acquisition_channel,
    count(case when completed_orders >= 1 then 1 end) as purchasing_orders,
    sum(total_revenue) as total_revenue,
    round(sum(total_revenue) / nullif(count(case when completed_orders >= 1 then 1 end), 0),2) as revenue_per_customer
from
    pre_agg
group by
    acquisition_channel;

-- How many customers fall into each revenue segment based on their total completed-order revenue?
with pre_agg as (select
    a.customer_id,
    sum(b.order_total) as total_revenue
from
    customers a
left join
    orders b
on
    a.customer_id = b.customer_id
and
    b.order_status = 'Completed'
group by
    a.customer_id),

segmenting as (select
    case when total_revenue >= 1000 then 'High-Value'
    when total_revenue >= 300 and total_revenue <= 1000 then 'Mid-Value'
    when total_revenue < 300 then 'Low-Value' end as customer_segment,
    total_revenue,
    customer_id
from
    pre_agg
where total_revenue is not null)

select customer_segment, count(customer_id) as customer_count, sum(total_revenue) as total_revenue, round(avg(total_revenue),2) as avg_customer_revenue
from segmenting group by customer_segment;

-- What percentage of NovaCart's total completed-order revenue is generated by its top 10% of purchasing customers?
with pre_agg as (select
    a.customer_id,
    sum(b.order_total) as total_revenue
from
    customers a
left join
    orders b
on
    a.customer_id = b.customer_id
and
    b.order_status = 'Completed'
group by
    a.customer_id),

deciles as(select
    customer_id,
    total_revenue,
    ntile(10) over(order by total_revenue desc) as revenue_deciles
from
    pre_agg
where
    total_revenue is not null)

select
    count(customer_id) as total_purchasing_customers,
    count(case when revenue_deciles = 1 then customer_id end) as top_10_decile_custs,
    sum(case when revenue_deciles = 1 then total_revenue else 0 end) as top_10_percent_revenue,
    sum(total_revenue) as total_revenue,
    round(sum(case when revenue_deciles = 1 then total_revenue else 0 end) * 100 / sum(total_revenue), 2) as revenue_contribution_pct
from
    deciles;

-- What is the average lifetime revenue per purchasing customer, and how does it vary by acquisition channel?
with pre_agg as(select
    a.acquisition_channel,
    a.customer_id,
    sum(b.order_total) as cutomer_total
from
    customers a
left join
    orders b
on
    a.customer_id = b.customer_id
and
    b.order_status = 'Completed'
group by
    a.acquisition_channel,
    a.customer_id)

select
    acquisition_channel,
    count(customer_id) as purchasing_customers,
    sum(cutomer_total) as total_lifetime_revenue,
    round(avg(cutomer_total), 2) as avg_customer_lifetime_revenue
from
    pre_agg
where
    cutomer_total is not null
group by
    acquisition_channel;

-- For each month, how many new customers signed up, how many of those customers made at least one completed purchase during that same month, 
-- and what was their purchase conversion rate?
SELECT
    DATE_TRUNC('month', c.signup_date)::DATE AS signup_month,
    COUNT(DISTINCT c.customer_id) AS new_customers,
    COUNT(DISTINCT o.customer_id) AS purchasing_customers,
    ROUND(
        COUNT(DISTINCT o.customer_id) * 100.0
        / NULLIF(COUNT(DISTINCT c.customer_id), 0),
        2
    ) AS purchase_conversion_rate
FROM
    customers c
LEFT JOIN
    orders o
    ON c.customer_id = o.customer_id
    AND o.order_status = 'Completed'
    AND DATE_TRUNC('month', c.signup_date)
        = DATE_TRUNC('month', o.order_timestamp)
GROUP BY
    DATE_TRUNC('month', c.signup_date)
ORDER BY
    signup_month;

