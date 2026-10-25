-- Customer Purchase Frequency by Acquisition Channel

with pre_agg as (select
    a.customer_id,
    a.acquisition_channel,
    count(b.order_id) as total_orders
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
    count(case when total_orders >= 1 then 1 end) as purchasing_customers,
    round(avg(case when total_orders >= 1 then total_orders end), 2) as avg_orders,
    round(sum(case when total_orders > 1 then 1 end) * 100 / 
    (count(case when total_orders >= 1 then 1 end)), 2) as repeat_purch_rate
from
    pre_agg
group by
    acquisition_channel
order by
    repeat_purch_rate desc;


-- Customer Churn and Inactivity Analysis

with inactivity as (
    select
        a.customer_id,
        a.acquisition_channel,
        max(b.order_timestamp) as last_purch_date
    from
        customers a
    left join
        orders b
    on
        a.customer_id = b.customer_id
    and
        b.order_status = 'Completed'
    group by
        a.customer_id, a.acquisition_channel
),

inactivity_status as (select
    acquisition_channel,
    customer_id,
    last_purch_date,
    case when (CURRENT_DATE - last_purch_date::DATE > 90) then 'inactive' else 'active' end as purch_status
from
    inactivity)

select
    acquisition_channel,
    count(case when last_purch_date IS NOT NULL then customer_id end) as purchasing_customers,
    count(case when purch_status = 'inactive' then 1 end) as inactive_user,
    (count(case when purch_status = 'inactive' then 1 end) * 100 /
    nullif(count(case when last_purch_date IS NOT NULL then customer_id end), 0), 2) as inactive_percent
from
    inactivity_status
group by
    acquisition_channel;

-- Customer Revenue Segmentation by Acquisition Channel;

with pre_agg as (select
    a.customer_id,
    sum(b.order_total) as lifetime_value,
    a.acquisition_channel
from
    customers a
inner join
    orders b
on
    a.customer_id = b.customer_id
and
    b.order_status = 'Completed'
group by
    a.customer_id, a.acquisition_channel),

segmented as (select
    acquisition_channel,
    customer_id,
    lifetime_value,
    case when lifetime_value >= 1000 then 'High Value'
    when lifetime_value >= 300 and lifetime_value < 1000 then 'Mid Value'
    else 'NA' end as customer_segment
from
    pre_agg)

select
    acquisition_channel,
    customer_segment,
    count(customer_id) as total_customers,
    round(sum(lifetime_value)) as total_revenue,
    round(avg(lifetime_value),2) as avg_lifetime_value
from
    segmented
group by
    acquisition_channel,
    customer_segment
order by
    acquisition_channel;

-- Acquisition Channel Quality — Revenue and Repeat Purchasing;

with pre_agg as (select
    a.acquisition_channel,
    a.customer_id,
    count(case when b.order_status = 'Completed' then b.order_id end) as total_completed_orders,
    sum(case when b.order_status = 'Completed' then b.order_total end) as lifetime_revenue
from
    customers a
left join
    orders b
on
    a.customer_id = b.customer_id
group by
    a.acquisition_channel,
    a.customer_id)

select
    acquisition_channel,
    count(customer_id) as total_customers,
    count(case when total_completed_orders >= 1 then customer_id end) as purch_customers,
    round(count(case when total_completed_orders >= 1 then customer_id end) * 100 /
    count(customer_id), 2) as conversion_rate,
    round(sum(lifetime_revenue) /
    count(case when total_completed_orders >= 1 then customer_id end)) as avg_lifetime_revenue,
    round(count(case when total_completed_orders > 1 then customer_id end) * 100 /
    count(case when total_completed_orders >= 1 then customer_id end), 2) as repeat_purchase_rate
from
    pre_agg
group by
    acquisition_channel;


-- Time to First Purchase by Acquisition Channel;

with pre_agg as (select
    a.customer_id,
    a.acquisition_channel,
    a.signup_date,
    min(b.order_timestamp) as first_order,
    count(b.order_id) as total_orders
from
    customers a
left join
    orders b
on
    a.customer_id = b.customer_id
and
    b.order_status = 'Completed'
group by
    a.customer_id,
    a.acquisition_channel,
    a.signup_date),

order_diff as (select
    acquisition_channel,
    customer_id,
    total_orders,
    signup_date,
    first_order,
    first_order::DATE - signup_date::DATE as diff_in_orders
from
    pre_agg)

select
    acquisition_channel,
    count(case when signup_date is not null then customer_id end) as registered_customers,
    count(case when total_orders >= 1 then customer_id end) as purchasing_customers,
    round(avg(diff_in_orders)) as avg_days_to_first_purchase,
    count(case when diff_in_orders between 0 and 7 then customer_id end) as fast_converters,
    count(case when diff_in_orders between 0 and 7 then customer_id end) * 100 / 
    count(case when total_orders >= 1 then customer_id end) as fast_conversion_rate
from
    order_diff
group by
    acquisition_channel;

-- Monthly Repeat Purchase Behaviour;
with pre_agg as (select
    EXTRACT(MONTH from signup_date::DATE) as signup_month,
    a.customer_id,
    count(b.order_id) as total_orders
from 
    customers a
left join
    orders b
on
    a.customer_id = b.customer_id
and
    b.order_status = 'Completed'
and
    EXTRACT(MONTH FROM a.signup_date:: DATE) = EXTRACT(MONTH FROM b.order_timestamp:: DATE)
group by
    EXTRACT(MONTH from signup_date::DATE),
    a.customer_id)

select
    signup_month,
    count(customer_id) as new_customers,
    count(case when total_orders >= 1 then customer_id end) as purchasing_customers,
    count(case when total_orders >= 2 then customer_id end) as repeat_purchases,
    count(case when total_orders >= 2 then customer_id end) * 100 /
    count(case when total_orders >= 1 then customer_id end) as repeat_purchase_rate
from
    pre_agg
group by
    signup_month
order by
    signup_month;


-- Customer Revenue Retention by Signup Cohort;
with pre_agg as (select
    a.customer_id,
    b.order_total,
    DATE_TRUNC('month', a.signup_date)::DATE AS signup_month,
    DATE_TRUNC('month', b.order_timestamp)::DATE AS order_month
from
    customers a
left join
    orders b
on
    a.customer_id = b.customer_id
and
    b.order_status = 'Completed'
order by
    signup_month),

cohort_revenue as (select
    signup_month,
    count(distinct customer_id) as cohort_size,
    sum(case when order_month = signup_month then order_total else 0 end) as month_0_revenue,
    sum(case when order_month = (signup_month + INTERVAL '1 month')::DATE then order_total end) as month_1_revenue,
    sum(case when order_month = (signup_month + INTERVAL '2 month')::DATE then order_total end) as month_2_revenue
from
    pre_agg
group by
    signup_month)

select
    signup_month,
    cohort_size,
    month_0_revenue,
    month_1_revenue,
    month_2_revenue,
    (month_1_revenue * 100) / month_0_revenue as month_1_revenue_retention
from
    cohort_revenue;

-- Customer Lifetime Value Ranking by Acquisition Channel
with pre_agg as(select
    a.acquisition_channel,
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
    a.acquisition_channel,
    a.customer_id),

pre_calc as (select
    acquisition_channel,
    total_revenue as channel_revenue,
    customer_id,
    ntile(10) over(partition by acquisition_channel order by total_revenue DESC) as percentile_revenue
from
    pre_agg)

select
    acquisition_channel,
    count(customer_id) as total_purchasing_customers,
    count(case when percentile_revenue = 1 then customer_id end) as top_10pct_customers,
    sum(channel_revenue) as channel_revenue,
    sum(case when percentile_revenue = 1 then channel_revenue end) as top_10pct_revenue,
    round(sum(case when percentile_revenue = 1 then channel_revenue end) * 100 /
    sum(channel_revenue), 2) as top_10pct_revenue_share
from
    pre_calc
group by
    acquisition_channel;