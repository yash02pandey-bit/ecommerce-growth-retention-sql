-- Monthly Revenue & Order Trends
with order_item as (select
    order_id,
    sum(quantity) as total_units_sold
from    
    order_items
group by
    order_id),

orders as (select
    order_id,
    date_trunc('month', order_timestamp)::Date as order_month,
    order_total as total_revenue,
    1 as total_orders
from
    orders
where
    order_status = 'Completed'
and
    order_timestamp >= '2025-01-01'
and 
    order_timestamp < '2027-01-01')

select
    b.order_month,
    sum(b.total_revenue) as total_revenue,
    sum(b.total_orders) as total_orders,
    round((sum(b.total_revenue) / sum(b.total_orders)), 2) as average_order_value,
    sum(a.total_units_sold) as total_units_sold
from
    order_item a
inner join
    orders b
on
    a.order_id = b.order_id
group by
    b.order_month
order by
    b.order_month;

-- Month-over-Month Revenue Growth
with pre_agg as (select
    date_trunc('month', order_timestamp)::Date as order_month,
    sum(order_total) as total_revenue
from
    orders
where
    order_status = 'Completed'
and
    order_timestamp <= '2026-12-31' 
and 
    order_timestamp >= '2025-01-01'
group by
    date_trunc('month', order_timestamp)::Date),

prev_rev as (select
    order_month,
    total_revenue,
    lag(total_revenue) over(order by order_month) as previous_month_revenue
from
    pre_agg),

pct_change as (select
    order_month,
    total_revenue,
    previous_month_revenue,
    (total_revenue - coalesce(previous_month_revenue, 0)) as revenue_change,
    round((total_revenue - previous_month_revenue) * 100 / coalesce(previous_month_revenue,0), 2) as revenue_growth_pct
from
    prev_rev)

select
    order_month,
    total_revenue,
    previous_month_revenue,
    revenue_change,
    revenue_growth_pct,
    case when previous_month_revenue is null then 'First Month'
    when total_revenue > previous_month_revenue then 'Growth'
    when total_revenue < previous_month_revenue then 'Decline'
    else 'No Change' end as revenue_trend
from
    pct_change;

-- Year-over-Year (YoY) Revenue Growth
with pre_agg as (select
    date_trunc('month', order_timestamp)::DATE as order_month,
    sum(order_total) as total_revenue
from
    orders
where 
    order_status = 'Completed'
and
    order_timestamp >= '2025-01-01'
and 
    order_timestamp < '2027-01-01'
group by
    date_trunc('month', order_timestamp)::DATE),

prev_reve as (select
    order_month,
    total_revenue,
    lag(total_revenue, 12) over(order by order_month) as prev_revenue
from
    pre_agg)

select
    order_month,
    total_revenue,
    prev_revenue,
    (total_revenue - coalesce(prev_revenue,0)) as reve_change,
    round((total_revenue - prev_revenue) * 100 / nullif(prev_revenue,0), 2) as revenue_growth_pct,
    case when prev_revenue is null then 'No Previous Year Data'
    when total_revenue > prev_revenue then 'Growth'
    when total_revenue < prev_revenue then 'Decline'
    else 'No Change' end as revenue_trend
from
    prev_reve
order by
    order_month;

-- Year-over-Year (YoY) Revenue Growth
-- Using the orders table, calculate monthly revenue for completed orders from January 2025 through December 2026, 
-- then compare each month with the same month in the previous year.
with data_prep as (select
    date_trunc('month', order_timestamp)::DATE as order_month,
    sum(order_total) as total_revenue
from
    orders
where
    order_timestamp >= '2025-01-01'
and
    order_timestamp <= '2026-12-31'
and
    order_status = 'Completed'
group by
   date_trunc('month', order_timestamp)::DATE),

calendar AS (
    select
        generate_series(
            date '2025-01-01',
            date '2026-12-01',
            interval '1 month'
        )::date AS order_month
),

monthly_revenue as (select
    c.order_month,
    coalesce(d.total_revenue, 0) as total_revenue
from
    calendar c
left join
    data_prep d
on
    c.order_month = d.order_month),

arranged as (select
    order_month,
    total_revenue,
    lag(total_revenue, 12) over(order by order_month) as prev_rev
from
    monthly_revenue)

select
    *,
    (total_revenue - coalesce(prev_rev, 0)) as revenue_change,
    (total_revenue - prev_rev) * 100 / (prev_rev) as pct_change,
    case when total_revenue > prev_rev then 'Growth'
    when total_revenue < prev_rev then 'Decline'
    when prev_rev is null then 'No Previous Year Data'
    else 'No Change' end as revenue_trend
from
    arranged;

-- Identify the Best and Worst Revenue Months
with calendar AS (
    select
        generate_series(
            date '2025-01-01',
            date '2026-12-01',
            interval '1 month'
        )::date AS order_month
),

pre_agg as (select
    date_trunc('month', order_timestamp)::Date as order_month,
    coalesce(sum(order_total),0) as total_revenue
from
    calendar b
left join
    orders a
on
    date_trunc('month', a.order_timestamp)::Date = b.order_month
and
    order_timestamp >= '2025-01-01'
and
    order_timestamp < '2027-01-01'   
and
    order_status = 'Completed'
group by
    date_trunc('month', order_timestamp)::Date
order by
    order_month),

ranking as (select
    *,
    rank() over(order by total_revenue desc) as highest_revenue_rank,
    rank() over(order by total_revenue) as lowest_revenue_rank
from
    pre_agg)

select
    *,
    case when highest_revenue_rank = 1 then 'Best Month'
    when lowest_revenue_rank = 1 then 'Worst Month'
    else 'Other Month' end as revenue_performance
from
    ranking;

-- Calculate the 3-Month Moving Average of Revenue
with calendar as (select
    generate_series(
        date '2025-01-01',
        date '2026-12-01',
        interval '1 month')::Date as order_month),

pre_agg as (select
    b.order_month as order_month,
    coalesce(sum(a.order_total),0) as total_revenue
from
    calendar b
left join
    orders a
on
    date_trunc('month', a.order_timestamp)::Date = b.order_month
and
    a.order_status = 'Completed'
and
    order_timestamp >= '2025-01-01'
and
    order_timestamp < '2027-01-01'
group by
    b.order_month
order by
    b.order_month),

averaging as (select
    *,
    round(avg(total_revenue) over(order by order_month 
    rows between 2 preceding and current row),2) as avg_3_months
from
    pre_agg)

select
    *,
    case when total_revenue > avg_3_months then 'Above Average'
    when total_revenue < avg_3_months then 'Below Average'
    when total_revenue = avg_3_months then 'Equal to Average' end as revenue_vs_moving_avg
from
    averaging;

-- Compare Monthly Revenue Against Its Moving Average
with calendar as (select
    generate_series(
        date '2025-01-01',
        date '2026-12-01',
        interval '1 month'
    )::Date as order_month),

pre_agg as (select
    b.order_month,
    coalesce(sum(a.order_total), 0) as total_revenue
from
    calendar b
left join
    orders a
on
    b.order_month = date_trunc('month', a.order_timestamp)::Date
and
    a.order_status = 'Completed'
and
    order_timestamp >= '2025-01-01'
and
    order_timestamp < '2027-01-01'
group by
    b.order_month),

averaging as (select
    *,
    round(avg(total_revenue) over(order by order_month rows between 2 preceding and current row), 2) as avg_3_month
from
    pre_agg)

select
    *,
    case when total_revenue > avg_3_month then 'Above Trend'
    when total_revenue < avg_3_month then 'Below Trend'
    else 'On Trend' end as revenue_trend,
    (total_revenue - avg_3_month) as revenue_difference,
    round((total_revenue - avg_3_month) * 100 / nullif((avg_3_month), 0), 2) as revenue_deviation_pct
from
    averaging;

-- Calculate Monthly Average Order Value (AOV)
with calendar as (select
    generate_series(
        date '2025-01-01',
        date '2026-12-01',
        interval '1 month'
    ) as order_month),

pre_agg as (select
    date_trunc('month', b.order_month)::Date as order_month,
    sum(a.order_total) as total_revenue,
    count(order_id) as total_orders
from
    calendar b
left join
    orders a
on
    b.order_month = date_trunc('month', a.order_timestamp)::Date
and
    a.order_status = 'Completed'
group by
    date_trunc('month', b.order_month)::Date
order by
    order_month),

aggregate as (select
    *,
    round(total_revenue / total_orders, 2) as monthly_aov
from
    pre_agg),

lags as (select
    *,
    lag(monthly_aov) over(order by order_month) as previous_month_aov
from
    aggregate)

select
    *,
    round((monthly_aov - previous_month_aov) * 100/ nullif((previous_month_aov), 0), 2) as aov_change_pct,
    case when monthly_aov > previous_month_aov then 'Increase'
    when monthly_aov < previous_month_aov then 'Decrease'
    when monthly_aov = previous_month_aov then 'No Change'
    else 'No Previous Month Data' end as aov_trend
from
    lags;

-- Analyse Revenue by Sales Channel Over Time
with calendar as (select
    generate_series(
        date '2025-01-01',
        date '2026-12-01',
        interval '1 month'
    )::DATE as order_month),

channels as (select
    distinct sales_channel as sales_channel
from
    orders
where
    sales_channel is not null),

monthly_calendar as (select
    c.order_month,
    s.sales_channel
from
    calendar c
cross join
    channels s
),

pre_agg as (select
    b.order_month,
    b.sales_channel,
    coalesce(sum(a.order_total),0) as total_revenue,
    count(a.order_id) as total_orders
from
    monthly_calendar b
left join
    orders a
on
    date_trunc('month', a.order_timestamp)::Date = b.order_month
and
    b.sales_channel = a.sales_channel
and
    a.order_status = 'Completed'
and 
    a.order_timestamp >= DATE '2025-01-01'
and 
    a.order_timestamp < DATE '2027-01-01'
group by
    b.order_month,
    b.sales_channel),

calculate as (select
    *,
    sum(total_revenue) over(partition by order_month) as total_monthly_revenue,
    lag(total_revenue) over(partition by sales_channel order by order_month) as last_month_channel_revenue
from
    pre_agg)

select
    order_month,
    sales_channel,
    total_revenue,
    total_orders,
    total_monthly_revenue,
    round((total_revenue) * 100.0 / nullif(total_monthly_revenue, 0), 2) as channel_revenue_share_pct,
    last_month_channel_revenue,
    round((total_revenue - last_month_channel_revenue) * 100.0 / nullif(last_month_channel_revenue, 0), 2) as mom_revenue_growth_pct
from
    calculate
order by
    order_month,
    sales_channel;

-- Weekday vs Weekend Revenue Analysis;

with pre_agg as (select
    case when extract(dow from b.order_timestamp) in (0,6) then 'Weekend' else 'Weekday' end as day_type,
    coalesce(sum(b.order_total),0) as total_revenue,
    count(b.order_id) as total_orders,
    count(distinct date(b.order_timestamp)) as active_days
from
    orders b
where
    b.order_status = 'Completed'
and
    date_trunc('month', b.order_timestamp)::Date >= '2025-01-01'
and
    date_trunc('month', b.order_timestamp)::Date <= '2026-12-01'
group by
    case when extract(dow from b.order_timestamp) in (0,6) then 'Weekend' else 'Weekday' end),

overall as (select
    *,
    sum(total_revenue) over() as overall_revenue
from
    pre_agg)

select
    *,
    round((total_revenue) / nullif(total_orders, 0), 2) as average_order_value,
    round((total_revenue) * 100.0 / nullif(overall_revenue, 0), 2) as revenue_share_pct,
    round((total_revenue) / nullif(active_days, 0), 2) as average_daily_revenue
from
    overall;

-- Revenue Seasonality by Month
with pre_agg as (select
    extract(month from order_timestamp)::integer as month_number,
    to_char(order_timestamp, 'Month') as month_name,
    coalesce(sum(order_total),0) as total_revenue,
    count(order_id) as total_orders
from
    orders
where
    order_status = 'Completed'
and
    order_timestamp >= '2025-01-01'
and
    order_timestamp < '2027-01-01'
group by
    extract(month from order_timestamp)::integer,
    to_char(order_timestamp, 'Month')
order by
    month_number),

aggregates as (select
    *,
    round(total_revenue / 2.0, 2) AS average_monthly_revenue
from
    pre_agg),

overall as (select
    *,
    round(avg(average_monthly_revenue) over(), 2) as overall_monthly_average
from
    aggregates)

select
    *,
    dense_rank() over(order by average_monthly_revenue desc) as revenue_rank,
    case when average_monthly_revenue > overall_monthly_average then 'High Season'
    when average_monthly_revenue < overall_monthly_average then 'Low Season'
    else 'Normal Season' end as seasonality_category
from
    overall;

-- Cumulative Revenue Throughout the Year
with pre_agg as (select
    extract(Year from order_timestamp)::integer as years,
    extract(Month from order_timestamp)::integer as month_number,
    to_char(order_timestamp, 'Month') as month_name,
    sum(coalesce(order_total, 0)) as monthly_revenue
from
    orders
where
    order_timestamp >= '2025-01-01'
and
    order_timestamp < '2027-01-01'
and
    order_status = 'Completed'
group by
    extract(Year from order_timestamp)::integer,
    extract(Month from order_timestamp)::integer,
    to_char(order_timestamp, 'Month')
order by
    years,
    month_number),

cumulative as (select
    *,
    sum(monthly_revenue) over(partition by years order by month_number rows between unbounded preceding and current row) as cumulative_revenue,
    sum(monthly_revenue) over(partition by years) as year_total_revenue
from
    pre_agg),

cumulative_rnk as (select
    *,
    dense_rank() over(partition by years order by cumulative_revenue desc) as cumulative_revenue_rnk
from
    cumulative)

select
    *,
    round((cumulative_revenue) * 100.0 / nullif((year_total_revenue), 0), 2) as yearly_revenue_contribution_pct
from
    cumulative_rnk;

-- Quarterly Revenue Growth
with pre_agg as (select
    extract(year from order_timestamp)::integer as years,
    extract(quarter from order_timestamp)::integer as quarters,
    case when extract(quarter from order_timestamp)::integer = 1 then 'Q1'
    when extract(quarter from order_timestamp)::integer = 2 then 'Q2'
    when extract(quarter from order_timestamp)::integer = 3 then 'Q3'
    when extract(quarter from order_timestamp)::integer = 4 then 'Q4' end as quarter_name,
    sum(coalesce(order_total, 0)) as total_revenue,
    count(order_id) as total_orders
from
    orders
where
    order_timestamp >= '2025-01-01'
and
    order_timestamp < '2027-01-01'
and
    order_status = 'Completed'
group by
    extract(year from order_timestamp)::integer,
    extract(quarter from order_timestamp)::integer,
    case when extract(quarter from order_timestamp)::integer = 1 then 'Q1'
    when extract(quarter from order_timestamp)::integer = 2 then 'Q2'
    when extract(quarter from order_timestamp)::integer = 3 then 'Q3'
    when extract(quarter from order_timestamp)::integer = 4 then 'Q4' end
order by
    years,
    quarters),

lagging as (select
    *,
    lag(total_revenue) over(order by years, quarters) as previous_quarter_revenue
from
    pre_agg)

select
    *,
    round((total_revenue - previous_quarter_revenue) * 100.0 / nullif((previous_quarter_revenue), 0), 2) as quarter_over_quarter_growth_pct,
    case when total_revenue > previous_quarter_revenue then 'Growth'
    when total_revenue < previous_quarter_revenue then 'Decline'
    else 'No Change' end as growth_category
from
    lagging;

-- Identify Consecutive Declining Revenue Months
with pre_agg as (select
    date_trunc('month', order_timestamp)::Date as order_month,
    sum(coalesce(order_total,0)) as monthly_revenue
from
    orders
where
    order_status = 'Completed'
and
    order_timestamp >= '2025-01-01'
and
    order_timestamp < '2027-01-01'
group by
    date_trunc('month', order_timestamp)::Date
order by
    order_month),

pre_calc as (select
    *,
    lag(monthly_revenue) over(order by order_month) as previous_month_revenue
from
    pre_agg),

pct_change as (select
    *,
    monthly_revenue - previous_month_revenue AS revenue_change,
    round((monthly_revenue - previous_month_revenue) * 100.0 / nullif((previous_month_revenue), 0), 2) as mom_growth_pct
from
    pre_calc),

groups as (select
    *,
    case when monthly_revenue < previous_month_revenue then 'Decline'
    when monthly_revenue > previous_month_revenue then 'Incline'
    when previous_month_revenue is null then 'First Month' else 'No Change' end as revenue_trend
from
    pct_change),

streaks as (select
    *,
    sum(case when revenue_trend = 'Decline' then 0 else 1 end) over(order by order_month) as decline_group
from
    groups),

strks as (select
    *,
    case when revenue_trend = 'Decline' then row_number() over (partition by decline_group order by order_month) else 0 end as consecutive_declining_months
from
    streaks
order by
    order_month)

select
    order_month,
    monthly_revenue,
    previous_month_revenue,
    revenue_change,
    mom_growth_pct,
    revenue_trend,
    consecutive_declining_months
from 
    strks
order by
    order_month;

-- Revenue vs Order Volume Analysis
with pre_agg as (select
    date_trunc('month', order_timestamp)::Date as order_month,
    sum(order_total) as monthly_revenue,
    count(order_id) as total_orders,
    round((sum(order_total) / count(order_id)), 2) as average_order_value
from
    orders
where
    order_status = 'Completed'
and
    order_timestamp >= '2025-01-01'
and        
    order_timestamp < '2027-01-01'
group by
    date_trunc('month', order_timestamp)::Date
order by
    order_month),

pre_calc as (select
    *,
    lag(monthly_revenue) over(order by order_month) as previous_month_revenue,
    lag(total_orders) over(order by order_month) as previous_month_orders,
    lag(average_order_value) over(order by order_month) as previous_month_aov
from
    pre_agg),

calc as (select
    *,
    round((monthly_revenue - previous_month_revenue) * 100.0 / nullif(previous_month_revenue, 0), 2) as revenue_growth_pct,
    round((total_orders - previous_month_orders) * 100.0 / nullif(previous_month_orders, 0), 2) as order_growth_pct,
    round((average_order_value - previous_month_aov) * 100.0 / nullif(previous_month_aov, 0), 2) as aov_growth_pct
from
    pre_calc)

select
    *,
    case when order_growth_pct > 0 and aov_growth_pct > 0 then 'Both'
    when order_growth_pct > 0 and aov_growth_pct <= 0 then 'Order Volume'
    when order_growth_pct <= 0 and aov_growth_pct > 0 then 'AOV Volume'
    else ' Neither' end as revenue_driver
from
    calc;

-- Identify Unusual Monthly Revenue Changes
with pre_agg as (select
    date_trunc('month', order_timestamp)::Date as order_month,
    sum(order_total) as monthly_revenue,
    lag(sum(order_total)) over(order by date_trunc('month', order_timestamp)::Date) as previous_month_revenue
from
    orders
where
    order_status = 'Completed'
and
    order_timestamp >= '2025-01-01'
and
    order_timestamp < '2027-01-01'
group by
    date_trunc('month', order_timestamp)::Date
order by
    order_month),

pre_calc as (select
    *,
    round((monthly_revenue - previous_month_revenue) * 100.0 / nullif(previous_month_revenue, 0), 2) as mom_growth_pct,
    round(avg(monthly_revenue) over(order by order_month rows between 2 preceding and current row), 2) as moving_avg_3_months
from
    pre_agg),

calc as (select
    *,
    (monthly_revenue - moving_avg_3_months) as revenue_deviation,
    round((monthly_revenue - moving_avg_3_months) * 100.0 / nullif(moving_avg_3_months, 0), 2) as revenue_deviation_pct
from
    pre_calc)

select
    *,
    case when revenue_deviation_pct > 20 then 'Unusually High'
    when revenue_deviation_pct < -20 then 'Unusually Low'
    else ' Normal' end as anomaly_category
from
    calc;

-- Monthly Revenue Contribution by Product Category
with products as (select
    date_trunc('month', o.order_timestamp)::Date as order_month,
    q.category,
    sum((p.quantity * p.unit_price) - (p.discount_amount)) as monthly_category_revenue
from
    orders o
inner join
    order_items p
on
    o.order_id = p.order_id
inner join
    products q
on
    q.product_id = p.product_id
and
    o.order_status = 'Completed'
and
    o.order_timestamp >= '2025-01-01'
and
    o.order_timestamp < '2027-01-01'
group by
    date_trunc('month', o.order_timestamp)::Date,
    q.category
order by
    order_month,
    category),

orders as (select
    date_trunc('month', order_timestamp)::Date as order_month,
    sum(order_total) as total_monthly_revenue
from
    orders
where
    order_status = 'Completed'
and
    order_timestamp >= '2025-01-01'
and
    order_timestamp < '2027-01-01'
group by
    date_trunc('month', order_timestamp)::Date
order by
    order_month),

joined as (select 
    a.*, 
    b.total_monthly_revenue
from
    products a
inner join
    orders b
on
    a.order_month = b.order_month
order by
    a.order_month),

calc as (select
    *,
    round((monthly_category_revenue) * 100.0 / nullif(total_monthly_revenue, 0), 2) as category_revenue_share_pct,
    lag(monthly_category_revenue) over(partition by category order by order_month) as previous_month_category_revenue,
    dense_rank() over(partition by order_month order by monthly_category_revenue desc) as category_revenue_rank
from
    joined)

select
    *,
    round((monthly_category_revenue - previous_month_category_revenue) * 100.0 / nullif(previous_month_category_revenue, 0), 2) as mom_revenue_growth_pct
from
    calc;

-- New vs Returning Customer Revenue Analysis
with first_purchase_date as (select
    customer_id,
    min(order_timestamp) as first_purchase_date
from
    orders
where
    order_status = 'Completed'
group by
    customer_id),

pre_agg as (select
    date_trunc('month', o.order_timestamp)::Date as order_month,
    case when date_trunc('month', o.order_timestamp)::Date = date_trunc('month', b.first_purchase_date)::Date then 'New Customer'
    else 'Returning Customer' end as customer_type,
    sum(o.order_total) as total_revenue,
    count(o.order_id) as total_orders,
    count(distinct a.customer_id) as total_customers
from
    customers a
inner join
    orders o
on
    a.customer_id = o.customer_id
left join
    first_purchase_date b
on
    a.customer_id = b.customer_id
where
    o.order_status = 'Completed'
and
    o.order_timestamp >= '2025-01-01'
and     
    o.order_timestamp < '2027-01-01'
group by
    date_trunc('month', o.order_timestamp)::Date,
    case when date_trunc('month', o.order_timestamp)::Date = date_trunc('month', b.first_purchase_date)::Date then 'New Customer'
    else 'Returning Customer' end
order by
    order_month,
    customer_type),

pre_calc as (select
    *,
    round((total_revenue) * 100.0 / nullif(sum(total_revenue) over(partition by order_month), 0), 2) as revenue_share_pct,
    lag(total_revenue) over(partition by customer_type order by order_month) as previous_month_revenue
from
    pre_agg)

select
    *,
    round((total_revenue - previous_month_revenue) * 100.0 / nullif(previous_month_revenue, 0), 2) as mom_revenue_growth_pct
from
    pre_calc;

-- Monthly Revenue Retention Analysis
with first_purchase_month as (select
    customer_id,
    min(date_trunc('month', order_timestamp)::Date) as customer_cohort_month
from
    orders
where
    order_status = 'Completed'
group by
    customer_id),


cohorts as (select
    a.customer_id,
    date_trunc('month', a.order_timestamp)::Date as order_month,
    b.customer_cohort_month,
    a.order_total
from
    orders a
inner join
    first_purchase_month b
on
    a.customer_id = b.customer_id
where
    a.order_status = 'Completed'
and
    a.order_timestamp >= '2025-01-01'
and
    a.order_timestamp < '2027-01-01'),

cohort_baseline as (select
    order_month,
    customer_cohort_month,
    (
            (extract(year from order_month) - extract(year from customer_cohort_month)) * 12
            + extract(month from order_month) - extract(month from customer_cohort_month)
        )::integer AS months_since_first_purchase,
    count(distinct customer_id) as active_customers,
    sum(order_total) as monthly_revenue
from
    cohorts
group by
    order_month,
    customer_cohort_month
order by
    customer_cohort_month,
    order_month),

baselines as (select
    customer_cohort_month,
    sum(case when months_since_first_purchase  = 0 then active_customers end) as original_cohort_size,
    sum(case when months_since_first_purchase  = 0 then monthly_revenue end) as cohort_month_revenue
from
    cohort_baseline
group by
    customer_cohort_month
order by
    customer_cohort_month)

select
    a.*,
    b.cohort_month_revenue,
    b.original_cohort_size
from
    cohort_baseline a
inner join
    baselines b
on
    a.customer_cohort_month = b.customer_cohort_month
group by
    a.order_month,
    a.customer_cohort_month,
    a.months_since_first_purchase,
    a.active_customers,
    a.monthly_revenue,
    b.cohort_month_revenue,
    b.original_cohort_size
order by
    a.customer_cohort_month,
    a.order_month;

--Monthly Revenue Run Rate Analysis
with pre_agg as (select
    date_trunc('month', order_timestamp)::Date as order_month,
    sum(order_total) as monthly_revenue,
    count(order_id) as total_orders,
    round((sum(order_total) / count(order_id)), 2) as average_order_value
from
    orders
where
    order_status = 'Completed'
and
    order_timestamp >= '2025-01-01'
and
    order_timestamp < '2027-01-01'
group by
    date_trunc('month', order_timestamp)::Date
order by
    order_month),

prev_month as (select
    *,
    lag(monthly_revenue) over(order by order_month) as previous_month_revenue
from
    pre_agg)

select
    *,
    round((monthly_revenue - previous_month_revenue) * 100.0 / nullif(previous_month_revenue, 0), 2) as mom_growth_pct,
    monthly_revenue * 12 as annualized_revenue_run_rate,
    case when monthly_revenue > previous_month_revenue then 'Growth'
    when monthly_revenue < previous_month_revenue then 'Decline'
    when previous_month_revenue is null then 'insufficient data' else 'No Change' end as run_rate_trend
from
    prev_month;

-- Diagnose Major Revenue Changes
with pre_agg as (select
    date_trunc('month', order_timestamp)::Date as order_month,
    sum(order_total) as monthly_revenue,
    count(order_id) as total_completed_orders,
    round(sum(order_total) / nullif(count(order_id), 0), 2) as average_order_value
from
    orders
where
    order_status = 'Completed'
and
    order_timestamp >= '2025-01-01'
and
    order_timestamp < '2027-01-01'
group by
    date_trunc('month', order_timestamp)::Date
order by
    order_month),

pre_calc as (select
    *,
    lag(monthly_revenue) over(order by order_month) as previous_month_revenue,
    lag(total_completed_orders) over(order by order_month) as previous_month_orders,
    lag(average_order_value) over(order by order_month) as previous_month_aov
from
    pre_agg),

calc as (select
    *,
    (monthly_revenue - previous_month_revenue) as revenue_change,
    round((monthly_revenue - previous_month_revenue) * 100.0 / nullif(previous_month_revenue, 0), 2) as mom_growth_pct,
    round((total_completed_orders - previous_month_orders) * 100.0 / nullif(previous_month_orders, 0), 2) as order_growth_pct,
    round((average_order_value - previous_month_aov) * 100.0 / nullif(previous_month_aov, 0), 2) as aov_growth_pct
from
    pre_calc)

select
    order_month,
    monthly_revenue,
    previous_month_revenue,
    revenue_change,
    mom_growth_pct,
    total_completed_orders,
    previous_month_orders,
    order_growth_pct,
    average_order_value,
    previous_month_aov,
    aov_growth_pct,
    case when mom_growth_pct > 20 then 'Significant Growth'
    when mom_growth_pct < -20 then 'Significant Decline'
    when mom_growth_pct between -20 and 20 then 'Normal Movement'
    when mom_growth_pct is null then 'Insufficient Data' else 'No Change' end as revenue_change_category
from
    calc;









 

























select * from orders limit 3;
select * from customers limit 3;
select * from order_items limit 3;
select * from products limit 3;