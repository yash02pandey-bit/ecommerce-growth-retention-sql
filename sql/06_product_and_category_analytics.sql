-- Which product categories generate the most revenue?
with pre_agg as (select
    a.category,
    sum(b.quantity) as units_sold,
    sum(b.item_total) as total_revenue,
    count(distinct c.order_id) as total_orders,
    count(distinct c.customer_id) as purchasing_customers
from
    products a
inner join
    order_items b
on
    a.product_id = b.product_id
inner join
    orders c
on
    c.order_id = b.order_id
and
    c.order_status = 'Completed'
group by
    a.category)

select
    *,
    round((total_revenue) * 100.0 / 
    (select sum(total_revenue) from pre_agg), 2) as revenue_contribution_pct
from
    pre_agg;

-- Identify the top 10 products by revenue
with pre_agg as (select
    a.product_id,
    a.product_name,
    a.category,
    sum(b.quantity) as units_sold,
    sum(b.item_total) as total_revenue,
    count(distinct c.order_id) as total_orders,
    count(distinct c.customer_id) as purchasing_customers
from
    products a
inner join
    order_items b
on
    a.product_id = b.product_id
inner join
    orders c
on
    b.order_id = c.order_id
and
    c.order_status = 'Completed'
group by
    a.product_id,
    a.product_name,
    a.category)

select
    product_name,
    total_revenue
from
    pre_agg
order by
    total_revenue desc
limit 10;

-- Find products with high return rates
with sales as (
    select
        a.order_item_id,
        a.product_id,
        a.quantity,
        a.item_total
    from
        order_items a
    inner join
        orders b
    on
        a.order_id = b.order_id
    and
        b.order_status = 'Completed'
),

returns as (
    select
        order_item_id,
        sum(quantity_returned) as units_returned
    from
        returns
    where
        return_status = 'Completed'
    group by
        order_item_id
),

product_metrics as(
    select
        a.product_name,
        sum(b.quantity) as units_sold,
        sum(coalesce(c.units_returned, 0)) as units_returned,
        sum(b.item_total) as total_revenue
    from
        products a
    inner join
        sales b
    on
        a.product_id = b.product_id
    left join
        returns c
    on
        b.order_item_id = c.order_item_id
    group by
        a.product_name
)

select
    product_name,
    units_sold,
    units_returned,
    total_revenue,
    round(units_returned * 100 / units_sold, 2) as return_rate_pct
from
    product_metrics;

-- Analyze product profitability by category
with products as (select
    product_id,
    category,
    cost_price
from
    products),

orders as (select
    order_id
from
    orders
where
    order_status = 'Completed'),

pre_agg as (select
    a.category,
    count(distinct a.product_id) as distinct_products_sold,
    sum(b.quantity) as units_sold,
    sum(b.item_total) as total_revenue,
    sum(b.quantity * a.cost_price) as total_cost
from
    products a
inner join
    order_items b
on
    a.product_id = b.product_id
inner join
    orders c
on
    b.order_id = c.order_id
group by
    a.category),

calc as (select
    distinct_products_sold,
    category,
    units_sold,
    total_revenue,
    total_cost,
    (total_revenue - total_cost) as gross_profit,
    round((total_revenue - total_cost) * 100 / total_revenue, 2) as gross_margin_pct
from
    pre_agg)

select * from calc order by gross_margin_pct desc;

-- Identify each category’s best-selling product
with product as (select
    product_id,
    category,
    product_name
from
    products),

orders as (select
    order_id
from
    orders
where
    order_status = 'Completed'),

merged as (select
    a.category,
    a.product_name,
    sum(c.item_total) as total_revenue,
    sum(c.quantity) as units_sold
from
    order_items c
inner join
    orders b
on
    c.order_id = b.order_id
inner join
    products a
on
    a.product_id = c.product_id
group by
    a.category,
    a.product_name),

ranking as (select
    category,
    product_name,
    units_sold,
    total_revenue,
    dense_rank() over(partition by category order by total_revenue desc) as rn
from
    merged)

select * from ranking where rn <= 3 order by category, rn;

-- Identify products with declining monthly revenue
with product as (select
    product_id,
    product_name
from
    products),

orders as (select
    order_id,
    EXTRACT(MONTH FROM order_timestamp::DATE) AS month_rev
from
    orders
where
    order_status = 'Completed'
),

merged as (select
    a.product_name,
    c.month_rev,
    sum(b.item_total) as monthly_revenue
from
    product a
inner join
    order_items b
on
    a.product_id = b.product_id
inner join
    orders c
on
    b.order_id = c.order_id
group by
    a.product_name,
    c.month_rev
),

revenue_compare as(select
    product_name,
    monthly_revenue,
    month_rev,
    lag(monthly_revenue) 
    over(partition by product_name order by month_rev) as last_month_rev
from
    merged)

select
    product_name,
    month_rev,
    (monthly_revenue - last_month_rev) as revenue_diff,
    round((monthly_revenue - last_month_rev) * 100 / (last_month_rev), 2) 
    as revenue_change_pct
from
    revenue_compare
where
    round((monthly_revenue - last_month_rev) * 100 / (last_month_rev), 2) < 0;

-- Analyze monthly category revenue growth
with pre_agg as (select
    a.category,
    EXTRACT(MONTH FROM c.order_timestamp::DATE) as month_rev,
    sum(b.item_total) as monthly_revenue
from
    products a
inner join
    order_items b
on
    a.product_id = b.product_id
inner join
    orders c
on
    c.order_id = b.order_id
and
    c.order_status = 'Completed'
group by
    a.category,
    EXTRACT(MONTH FROM c.order_timestamp::DATE)),

revenue_compare as (select
    *, 
    lag(monthly_revenue) over(partition by category order by month_rev) as prev_month_rev
from
    pre_agg)

select
    category,
    month_rev,
    monthly_revenue,
    prev_month_rev,
    (monthly_revenue - prev_month_rev) as revenue_change,
    round((monthly_revenue - prev_month_rev) * 100 / 
    prev_month_rev, 2) as revenue_change_pct
from
    revenue_compare
order by
    category,
    month_rev;

-- Identify products with the highest revenue concentration

with product_name as(
    select
        a.product_id,
        a.product_name,
        a.category,
        sum(b.item_total) as product_revenue
    from
        products a
    inner join
        order_items b
    on
        a.product_id = b.product_id
    inner join
        orders c
    on
        b.order_id = c.order_id
    and
        c.order_status = 'Completed'
    group by
        a.product_id,
        a.product_name,
        a.category
),

category as(select
    product_name,
    category,
    product_revenue,
    sum(product_revenue) over(partition by category) as category_revenue
from
    product_name)

select
    product_name,
    category,
    product_revenue,
    category_revenue,
    round((product_revenue * 100) / category_revenue, 2) as category_revenue_share_pct,
    dense_rank() over(PARTITION BY category
    order by product_revenue desc) as prod_rank
from
    category;

-- Find products with revenue growth above their category average

with pre_agg as(select
    a.product_id,
    a.product_name,
    sum(case when c.order_timestamp::DATE between '2026-01-01' and '2026-06-30'
    then b.item_total end) as first_half_revenue,
    sum(case when c.order_timestamp::DATE between '2026-07-01' and '2026-12-31'
    then b.item_total end) as second_half_revenue
from
    products a
inner join
    order_items b
on
    a.product_id = b.product_id
inner join
    orders c
on
    c.order_id = b.order_id
and
    c.order_status = 'Completed'
group by
    a.product_name,
    a.product_id),

agg as (select 
    *,
    round((second_half_revenue - first_half_revenue) * 100 / 
    nullif(first_half_revenue, 0), 2) 
    as revenue_growth_pct
from
    pre_agg
where
    first_half_revenue <> 0),

pre_final as (select
    a.*,
    round(avg(revenue_growth_pct) over(partition by b.category), 2) 
    as category_avg_growth_pct
from
    agg a
inner join
    products b
on
    a.product_id = b.product_id)

select
    product_id,
    product_name,
    first_half_revenue,
    second_half_revenue,
    revenue_growth_pct,
    category_avg_growth_pct
from
    pre_final
where
    revenue_growth_pct > category_avg_growth_pct;

-- Identify products with high revenue but low sales volume

with product_level as(
    select
        a.product_id,
        a.product_name,
        a.category,
        sum(b.quantity) as units_sold,
        sum(b.item_total) as product_revenue
    from
        products a
    inner join
        order_items b
    on
        a.product_id = b.product_id
    inner join
        orders c
    on
        c.order_id = b.order_id
    and
        c.order_status = 'Completed'
    group by
        a.product_id,
        a.product_name,
        a.category
),

category_level as(
    select
        *,
        round(avg(units_sold) over(partition by category), 2) as category_avg_units_sold,
        round(avg(product_revenue) over(partition by category), 2) as category_avg_product_revenue
    from
        product_level
)

select 
    * 
from 
    category_level 
where
    product_revenue > category_avg_product_revenue
and
    units_sold < category_avg_units_sold;

-- Calculate each product's cumulative revenue contribution

with pre_agg as (select
    a.product_id,
    a.category,
    a.product_name,
    sum(b.item_total) as product_revenue
from
    products a
inner join
    order_items b
on
    a.product_id = b.product_id
inner join
    orders c
on
    b.order_id = c.order_id
and
    c.order_status = 'Completed'
group by
    a.product_id,
    a.product_name,
    a.category),

cat_agg as (select
    product_id,
    category,
    product_name,
    product_revenue,
    sum(product_revenue) over(partition by category) as category_revenue,
    sum(product_revenue) over(partition by category order by product_revenue DESC
    , product_id rows between unbounded preceding and current row) as cumu_revenue,
    row_number() over(partition by category 
    order by product_revenue desc, product_id) as revenue_rank
from
    pre_agg)

select
    *,
    round((product_revenue) * 100 / category_revenue, 2) as product_revenue_share_pct,
    round((cumu_revenue) * 100 / category_revenue, 2) as cumu_share
from
    cat_agg;


-- Identify products driving 80% of category revenue

with pre_agg as (select
    a.product_id,
    a.product_name,
    a.category,
    sum(b.item_total) as product_revenue
from
    products a
inner join
    order_items b
on
    a.product_id = b.product_id
inner join
    orders c
on
    b.order_id = c.order_id
and
    c.order_status = 'Completed'
group by
    a.product_id,
    a.product_name,
    a.category),

category as(
    select
        product_id,
        product_name,
        category,
        product_revenue,
        sum(product_revenue) over(partition by category) as category_revenue,
        sum(product_revenue) over(partition by category order by product_revenue desc
        , product_id rows between unbounded preceding and current row) as cum_rev,
        row_number() over(partition by category order by product_revenue desc, product_id) as rev_rank
    from
        pre_agg),

pct as (select
    *,
    round((cum_rev) * 100 / category_revenue, 2) as cumu_share
from
    category),

prev_share as (
    select
        *,
        lag(cumu_share, 1, 0) over (
            partition by category
            order by rev_rank
        ) as previous_cumu_share
    from pct
)

select
    *,
    case
        when previous_cumu_share < 80.0 then 'Yes'
        else 'No'
    end as within_80_pct
from prev_share
order by category, rev_rank;

-- Identify products with no sales in the last 90 days

with pre_agg as(select
    a.product_id,
    a.product_name,
    a.category,
    sum((b.quantity)) as historical_units_sold,
    sum((b.item_total)) as historical_revenue,
    max(c.order_timestamp::DATE) as last_sale_date
from
    products a
left join
    order_items b
on
    a.product_id = b.product_id
inner join
    orders c
on
    b.order_id = c.order_id
and
    c.order_status = 'Completed'
group by
    a.product_id,
    a.product_name,
    a.category)

select
    *,
    current_date - last_sale_date as since_days_last_ordered
from
    pre_agg
where 
    last_sale_date is null or current_date - last_sale_date > 90;

















select * from products limit 3;
select * from orders limit 3;
select * from order_items limit 3;
-- select * from returns limit 3;