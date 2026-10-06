import os
import random
from datetime import datetime, timedelta

import numpy as np
import pandas as pd
from faker import Faker


# ============================================================
# CONFIGURATION
# ============================================================

SEED = 42

random.seed(SEED)
np.random.seed(SEED)

fake = Faker()
Faker.seed(SEED)

OUTPUT_DIR = "data/raw"

os.makedirs(OUTPUT_DIR, exist_ok=True)


# ============================================================
# HELPER FUNCTIONS
# ============================================================

def random_date(start_date, end_date):
    """
    Generate a random date between start_date and end_date.
    """
    delta = end_date - start_date
    return start_date + timedelta(days=random.randint(0, delta.days))


def random_timestamp(start_date, end_date):
    """
    Generate a random timestamp between two dates.
    """
    delta = end_date - start_date
    random_seconds = random.randint(0, int(delta.total_seconds()))
    return start_date + timedelta(seconds=random_seconds)


# ============================================================
# 1. CUSTOMERS
# ============================================================

print("Generating customers...")

N_CUSTOMERS = 50_000

acquisition_channels = [
    "Organic Search",
    "Paid Search",
    "Social Media",
    "Email",
    "Referral",
    "Direct",
    "Affiliate"
]

acquisition_weights = [
    0.25,
    0.18,
    0.16,
    0.12,
    0.10,
    0.12,
    0.07
]

genders = ["Male", "Female", "Other"]

cities = [
    "Paris",
    "Lyon",
    "Marseille",
    "Toulouse",
    "Bordeaux",
    "Lille",
    "Nantes",
    "Nice",
    "Montpellier",
    "Strasbourg",
    "Rouen",
    "Rennes",
    "Grenoble",
    "Dijon",
    "Angers"
]

customer_start = datetime(2025, 1, 1)
customer_end = datetime(2026, 12, 31)

customers = []

for customer_id in range(1, N_CUSTOMERS + 1):

    signup_date = random_timestamp(
        customer_start,
        customer_end
    )

    # Introduce realistic missing demographic data
    gender = random.choice(genders)

    if random.random() < 0.08:
        gender = None

    city = random.choice(cities)

    if random.random() < 0.06:
        city = None

    customers.append({
        "customer_id": customer_id,
        "first_name": fake.first_name(),
        "last_name": fake.last_name(),
        "email": f"customer_{customer_id}@example.com",
        "gender": gender,
        "date_of_birth": fake.date_of_birth(
            minimum_age=18,
            maximum_age=70
        ),
        "city": city,
        "country": "France",
        "signup_date": signup_date,
        "acquisition_channel": np.random.choice(
            acquisition_channels,
            p=acquisition_weights
        ),
        "customer_status": np.random.choice(
            ["Active", "Inactive", "Churned"],
            p=[0.72, 0.18, 0.10]
        )
    })


customers_df = pd.DataFrame(customers)

customers_df.to_csv(
    f"{OUTPUT_DIR}/customers.csv",
    index=False
)

print(f"Customers generated: {len(customers_df):,}")


# ============================================================
# 2. PRODUCTS
# ============================================================

print("Generating products...")

N_PRODUCTS = 1_000

product_categories = {
    "Electronics": [
        "Smartphones",
        "Laptops",
        "Headphones",
        "Smartwatches",
        "Accessories"
    ],
    "Home & Kitchen": [
        "Cookware",
        "Furniture",
        "Kitchen Appliances",
        "Home Decor",
        "Storage"
    ],
    "Fashion": [
        "Men Clothing",
        "Women Clothing",
        "Shoes",
        "Accessories",
        "Sportswear"
    ],
    "Beauty": [
        "Skincare",
        "Haircare",
        "Makeup",
        "Fragrance",
        "Personal Care"
    ],
    "Sports": [
        "Fitness Equipment",
        "Running",
        "Cycling",
        "Outdoor",
        "Sports Accessories"
    ],
    "Grocery": [
        "Snacks",
        "Beverages",
        "Staples",
        "Dairy",
        "Organic"
    ]
}

brands = [
    "NovaTech",
    "UrbanCore",
    "EverLife",
    "PeakPro",
    "HomeEase",
    "StyleHub",
    "PureGlow",
    "FreshMart",
    "ActiveX",
    "DailyChoice"
]

products = []

for product_id in range(1, N_PRODUCTS + 1):

    category = random.choice(
        list(product_categories.keys())
    )

    subcategory = random.choice(
        product_categories[category]
    )

    # Different price ranges by category
    if category == "Electronics":
        unit_price = round(
            np.random.lognormal(mean=5.3, sigma=0.65), 2
        )
        unit_price = min(max(unit_price, 25), 2500)

    elif category == "Home & Kitchen":
        unit_price = round(
            np.random.lognormal(mean=4.2, sigma=0.55), 2
        )
        unit_price = min(max(unit_price, 10), 1000)

    elif category == "Fashion":
        unit_price = round(
            np.random.lognormal(mean=3.7, sigma=0.45), 2
        )
        unit_price = min(max(unit_price, 10), 500)

    elif category == "Beauty":
        unit_price = round(
            np.random.lognormal(mean=3.4, sigma=0.40), 2
        )
        unit_price = min(max(unit_price, 5), 300)

    elif category == "Sports":
        unit_price = round(
            np.random.lognormal(mean=4.0, sigma=0.50), 2
        )
        unit_price = min(max(unit_price, 10), 800)

    else:
        unit_price = round(
            np.random.lognormal(mean=2.7, sigma=0.35), 2
        )
        unit_price = min(max(unit_price, 2), 150)

    # Cost price is normally below selling price
    margin = np.random.uniform(0.45, 0.80)

    cost_price = round(
        unit_price * margin,
        2
    )

    launch_date = random_date(
        datetime(2024, 1, 1),
        datetime(2026, 6, 30)
    ).date()

    products.append({
        "product_id": product_id,
        "product_name": f"{brands[product_id % len(brands)]} "
                        f"{subcategory} {product_id}",
        "category": category,
        "subcategory": subcategory,
        "brand": random.choice(brands),
        "unit_price": unit_price,
        "cost_price": cost_price,
        "launch_date": launch_date,
        "product_status": np.random.choice(
            ["Active", "Inactive", "Discontinued"],
            p=[0.82, 0.13, 0.05]
        )
    })


products_df = pd.DataFrame(products)

products_df.to_csv(
    f"{OUTPUT_DIR}/products.csv",
    index=False
)

print(f"Products generated: {len(products_df):,}")


# ============================================================
# 3. MARKETING CAMPAIGNS
# ============================================================

print("Generating marketing campaigns...")

N_CAMPAIGNS = 100

campaigns = []

campaign_start = datetime(2025, 1, 1)
campaign_end = datetime(2026, 12, 31)

campaign_channels = [
    "Organic Search",
    "Paid Search",
    "Social Media",
    "Email",
    "Referral",
    "Direct",
    "Affiliate"
]

for campaign_id in range(1, N_CAMPAIGNS + 1):

    start_date = random_date(
        campaign_start,
        campaign_end - timedelta(days=30)
    )

    duration = random.randint(7, 45)

    end_date = min(
        start_date + timedelta(days=duration),
        campaign_end
    )

    budget = round(
        random.uniform(5_000, 100_000),
        2
    )

    spend = round(
        budget * random.uniform(0.65, 1.05),
        2
    )

    channel = random.choice(campaign_channels)

    campaigns.append({
        "campaign_id": campaign_id,
        "campaign_name": f"{channel} Campaign {campaign_id}",
        "acquisition_channel": channel,
        "campaign_start": start_date.date(),
        "campaign_end": end_date.date(),
        "campaign_budget": budget,
        "campaign_spend": spend
    })


campaigns_df = pd.DataFrame(campaigns)

campaigns_df.to_csv(
    f"{OUTPUT_DIR}/marketing_campaigns.csv",
    index=False
)

print(
    f"Marketing campaigns generated: "
    f"{len(campaigns_df):,}"
)

# ============================================================
# 4. ORDERS + ORDER ITEMS
# ============================================================

print("\nGenerating orders and order items...")

N_ORDERS = 200_000

sales_channels = [
    "Web",
    "iOS",
    "Android"
]

sales_channel_weights = [
    0.45,
    0.30,
    0.25
]

order_statuses = [
    "Completed",
    "Cancelled",
    "Pending"
]

order_status_weights = [
    0.87,
    0.08,
    0.05
]

shipping_cities = cities

order_rows = []
order_item_rows = []

order_item_id = 1

# Customers with higher probability of becoming repeat purchasers
customer_ids = customers_df["customer_id"].values

# Give some customers substantially higher purchase probability.
customer_weights = np.random.lognormal(
    mean=0,
    sigma=1.0,
    size=len(customer_ids)
)

customer_weights = (
    customer_weights /
    customer_weights.sum()
)

selected_customers = np.random.choice(
    customer_ids,
    size=N_ORDERS,
    replace=True,
    p=customer_weights
)


for order_id in range(1, N_ORDERS + 1):

    customer_id = int(selected_customers[order_id - 1])

    customer = customers_df[
        customers_df["customer_id"] == customer_id
    ].iloc[0]

    # Orders can only occur after customer signup
    order_start = customer["signup_date"]

    order_end = datetime(2026, 12, 31)

    # Protect against customers signing up very late
    if order_start > order_end:
        order_start = datetime(2026, 1, 1)

    order_timestamp = random_timestamp(
        order_start,
        order_end
    )

    sales_channel = np.random.choice(
        sales_channels,
        p=sales_channel_weights
    )

    order_status = np.random.choice(
        order_statuses,
        p=order_status_weights
    )

    shipping_city = customer["city"]

    if pd.isna(shipping_city):
        shipping_city = random.choice(shipping_cities)

    shipping_country = "France"

    # --------------------------------------------------------
    # ORDER ITEMS
    # --------------------------------------------------------

    # Most orders contain 1–3 products
    number_of_items = np.random.choice(
        [1, 2, 3, 4, 5],
        p=[0.45, 0.30, 0.15, 0.07, 0.03]
    )

    selected_products = np.random.choice(
        products_df["product_id"].values,
        size=number_of_items,
        replace=False
    )

    order_subtotal = 0

    for product_id in selected_products:

        product = products_df[
            products_df["product_id"] == product_id
        ].iloc[0]

        quantity = np.random.choice(
            [1, 2, 3],
            p=[0.75, 0.20, 0.05]
        )

        unit_price = float(product["unit_price"])

        # Order-level discount behaviour
        discount_percentage = np.random.choice(
            [0, 0.05, 0.10, 0.15, 0.20],
            p=[0.55, 0.20, 0.15, 0.07, 0.03]
        )

        gross_item_value = (
            quantity *
            unit_price
        )

        discount_amount = round(
            gross_item_value *
            discount_percentage,
            2
        )

        item_total = round(
            gross_item_value -
            discount_amount,
            2
        )

        order_subtotal += item_total

        order_item_rows.append({
            "order_item_id": order_item_id,
            "order_id": order_id,
            "product_id": int(product_id),
            "quantity": int(quantity),
            "unit_price": unit_price,
            "discount_amount": discount_amount,
            "item_total": item_total
        })

        order_item_id += 1

    # --------------------------------------------------------
    # SHIPPING
    # --------------------------------------------------------

    if order_subtotal >= 75:
        shipping_fee = 0
    else:
        shipping_fee = round(
            random.uniform(2.99, 8.99),
            2
        )

    order_discount = round(
        sum(
            item["discount_amount"]
            for item in order_item_rows[-number_of_items:]
        ),
        2
    )

    order_total = round(
        order_subtotal + shipping_fee,
        2
    )

    # Cancelled orders may still have an order value,
    # which is useful for analytical debugging.
    order_rows.append({
        "order_id": order_id,
        "customer_id": customer_id,
        "order_timestamp": order_timestamp,
        "order_status": order_status,
        "sales_channel": sales_channel,
        "shipping_city": shipping_city,
        "shipping_country": shipping_country,
        "discount_amount": order_discount,
        "shipping_fee": shipping_fee,
        "order_total": order_total
    })


orders_df = pd.DataFrame(order_rows)
order_items_df = pd.DataFrame(order_item_rows)


# ============================================================
# SAVE ORDERS
# ============================================================

orders_df.to_csv(
    f"{OUTPUT_DIR}/orders.csv",
    index=False
)

order_items_df.to_csv(
    f"{OUTPUT_DIR}/order_items.csv",
    index=False
)


print(f"Orders generated:       {len(orders_df):,}")
print(f"Order items generated:  {len(order_items_df):,}")


# ============================================================
# ORDER QUALITY CHECKS
# ============================================================

print("\nOrder status distribution:")

print(
    orders_df["order_status"]
    .value_counts()
)


print("\nSales channel distribution:")

print(
    orders_df["sales_channel"]
    .value_counts()
)


print("\nAverage order value:")

print(
    round(
        orders_df["order_total"].mean(),
        2
    )
)

# ============================================================
# 5. PAYMENTS
# ============================================================

print("\nGenerating payments...")

payment_methods = [
    "Credit Card",
    "Debit Card",
    "PayPal",
    "Apple Pay",
    "Google Pay"
]

payment_method_weights = [
    0.35,
    0.20,
    0.18,
    0.15,
    0.12
]

failure_reasons = [
    "Insufficient Funds",
    "Bank Declined",
    "Card Expired",
    "Authentication Failed",
    "Technical Error",
    "Fraud Check Failed"
]

payment_rows = []

payment_id = 1

# Only orders that have a realistic chance of reaching payment
eligible_orders = orders_df[
    orders_df["order_status"].isin(
        ["Completed", "Pending", "Cancelled"]
    )
]


for _, order in eligible_orders.iterrows():

    order_id = int(order["order_id"])

    order_timestamp = order["order_timestamp"]

    order_amount = float(order["order_total"])

    # --------------------------------------------------------
    # DETERMINE NUMBER OF PAYMENT ATTEMPTS
    # --------------------------------------------------------

    # Most orders have one attempt.
    # Some have multiple attempts due to failures.

    number_of_attempts = np.random.choice(
        [1, 2, 3],
        p=[0.82, 0.14, 0.04]
    )

    payment_success = False

    for attempt in range(number_of_attempts):

        payment_method = np.random.choice(
            payment_methods,
            p=payment_method_weights
        )

        # Slightly different success rates by payment method
        method_success_probability = {
            "Credit Card": 0.93,
            "Debit Card": 0.91,
            "PayPal": 0.96,
            "Apple Pay": 0.97,
            "Google Pay": 0.95
        }

        success_probability = (
            method_success_probability[payment_method]
        )

        # If an earlier attempt failed,
        # later attempts have a slightly higher chance
        # of succeeding.
        if attempt > 0:
            success_probability += 0.02

        success = (
            random.random() <
            success_probability
        )

        if success:

            payment_status = "Paid"
            failure_reason = None
            payment_success = True

            payment_timestamp = (
                order_timestamp +
                timedelta(
                    seconds=random.randint(10, 900)
                )
            )

            payment_rows.append({
                "payment_id": payment_id,
                "order_id": order_id,
                "payment_timestamp": payment_timestamp,
                "payment_method": payment_method,
                "payment_status": payment_status,
                "amount": order_amount,
                "failure_reason": failure_reason
            })

            payment_id += 1

            # Stop after successful payment
            break

        else:

            payment_status = "Failed"

            failure_reason = random.choice(
                failure_reasons
            )

            payment_timestamp = (
                order_timestamp +
                timedelta(
                    seconds=random.randint(10, 900)
                )
            )

            payment_rows.append({
                "payment_id": payment_id,
                "order_id": order_id,
                "payment_timestamp": payment_timestamp,
                "payment_method": payment_method,
                "payment_status": payment_status,
                "amount": order_amount,
                "failure_reason": failure_reason
            })

            payment_id += 1


payments_df = pd.DataFrame(payment_rows)


# ============================================================
# SAVE PAYMENTS
# ============================================================

payments_df.to_csv(
    f"{OUTPUT_DIR}/payments.csv",
    index=False
)


# ============================================================
# PAYMENT QUALITY CHECKS
# ============================================================

print(
    f"Payment records generated: "
    f"{len(payments_df):,}"
)

print("\nPayment status distribution:")

print(
    payments_df["payment_status"]
    .value_counts()
)

print("\nPayment method distribution:")

print(
    payments_df["payment_method"]
    .value_counts()
)

print("\nPayment failure reasons:")

print(
    payments_df.loc[
        payments_df["payment_status"] == "Failed",
        "failure_reason"
    ].value_counts()
)

print("\nAverage payment amount:")

print(
    round(
        payments_df["amount"].mean(),
        2
    )
)

# ============================================================
# 6. RETURNS + REFUNDS
# ============================================================

print("\nGenerating returns...")

return_reasons = [
    "Product Defective",
    "Wrong Product",
    "Wrong Size",
    "Changed Mind",
    "Product Not as Expected",
    "Damaged During Delivery",
    "Late Delivery"
]

return_reason_weights = [
    0.18,
    0.10,
    0.18,
    0.20,
    0.15,
    0.12,
    0.07
]

return_statuses = [
    "Approved",
    "Completed",
    "Rejected"
]

return_status_weights = [
    0.15,
    0.80,
    0.05
]

return_rows = []

return_id = 1

# ------------------------------------------------------------
# Only completed/paid orders should normally generate returns
# ------------------------------------------------------------

paid_order_ids = set(
    payments_df.loc[
        payments_df["payment_status"] == "Paid",
        "order_id"
    ]
)

eligible_order_items = order_items_df[
    order_items_df["order_id"].isin(paid_order_ids)
].copy()


for _, item in eligible_order_items.iterrows():

    # Overall return probability
    # ~7% of eligible order items become returns
    if random.random() > 0.07:
        continue

    order_item_id = int(item["order_item_id"])
    order_id = int(item["order_id"])

    quantity = int(item["quantity"])
    unit_price = float(item["unit_price"])

    # Usually customers return only part of the quantity
    quantity_returned = np.random.choice(
        range(1, quantity + 1)
    )

    refund_amount = round(
        quantity_returned * unit_price,
        2
    )

    # Find original order timestamp
    order_timestamp = orders_df.loc[
        orders_df["order_id"] == order_id,
        "order_timestamp"
    ].iloc[0]

    # Return happens between 1 and 45 days after purchase
    return_date = (
        order_timestamp +
        timedelta(
            days=random.randint(1, 45)
        )
    )

    return_reason = np.random.choice(
        return_reasons,
        p=return_reason_weights
    )

    return_status = np.random.choice(
        return_statuses,
        p=return_status_weights
    )

    return_rows.append({
        "return_id": return_id,
        "order_item_id": order_item_id,
        "return_date": return_date,
        "quantity_returned": quantity_returned,
        "return_reason": return_reason,
        "refund_amount": refund_amount,
        "return_status": return_status
    })

    return_id += 1


returns_df = pd.DataFrame(return_rows)


# ============================================================
# SAVE RETURNS
# ============================================================

returns_df.to_csv(
    f"{OUTPUT_DIR}/returns.csv",
    index=False
)


# ============================================================
# RETURN QUALITY CHECKS
# ============================================================

print(
    f"Returns generated: "
    f"{len(returns_df):,}"
)

print("\nReturn status distribution:")

print(
    returns_df["return_status"]
    .value_counts()
)

print("\nReturn reason distribution:")

print(
    returns_df["return_reason"]
    .value_counts()
)

print("\nTotal refund amount:")

print(
    round(
        returns_df["refund_amount"].sum(),
        2
    )
)

print("\nAverage refund amount:")

print(
    round(
        returns_df["refund_amount"].mean(),
        2
    )
)

# ============================================================
# 7. SESSIONS + EVENTS
# ============================================================

print("\nGenerating sessions and events...")

N_SESSIONS = 600_000

device_types = [
    "Desktop",
    "Mobile",
    "Tablet"
]

device_weights = [
    0.35,
    0.55,
    0.10
]

landing_pages = [
    "Home",
    "Search",
    "Category",
    "Product",
    "Campaign",
    "Offers"
]

landing_page_weights = [
    0.20,
    0.25,
    0.15,
    0.20,
    0.10,
    0.10
]

session_start_date = datetime(2025, 1, 1)
session_end_date = datetime(2026, 12, 31)

session_rows = []
event_rows = []

event_id = 1

# ------------------------------------------------------------
# Customer weights
# ------------------------------------------------------------

# Some customers naturally visit more frequently.
customer_session_weights = np.random.lognormal(
    mean=0,
    sigma=1.0,
    size=len(customers_df)
)

customer_session_weights = (
    customer_session_weights /
    customer_session_weights.sum()
)

customer_ids = customers_df["customer_id"].values


# ------------------------------------------------------------
# Generate sessions
# ------------------------------------------------------------

for session_id in range(1, N_SESSIONS + 1):

    # --------------------------------------------------------
    # Customer vs anonymous session
    # --------------------------------------------------------

    if random.random() < 0.75:

        customer_id = int(
            np.random.choice(
                customer_ids,
                p=customer_session_weights
            )
        )

        customer = customers_df[
            customers_df["customer_id"] == customer_id
        ].iloc[0]

        # Session after signup
        session_start = random_timestamp(
            customer["signup_date"],
            session_end_date
        )

        acquisition_channel = (
            customer["acquisition_channel"]
        )

    else:

        customer_id = None

        session_start = random_timestamp(
            session_start_date,
            session_end_date
        )

        acquisition_channel = np.random.choice(
            acquisition_channels,
            p=acquisition_weights
        )


    # --------------------------------------------------------
    # Device
    # --------------------------------------------------------

    device_type = np.random.choice(
        device_types,
        p=device_weights
    )

    landing_page = np.random.choice(
        landing_pages,
        p=landing_page_weights
    )


    # --------------------------------------------------------
    # Session duration
    # --------------------------------------------------------

    session_duration = int(
        np.random.lognormal(
            mean=4.0,
            sigma=0.7
        )
    )

    session_duration = min(
        max(session_duration, 10),
        3600
    )

    session_end = (
        session_start +
        timedelta(
            seconds=session_duration
        )
    )


    session_rows.append({
        "session_id": session_id,
        "customer_id": customer_id,
        "session_start": session_start,
        "session_end": session_end,
        "device_type": device_type,
        "acquisition_channel": acquisition_channel,
        "landing_page": landing_page
    })


    # ========================================================
    # EVENT FUNNEL
    # ========================================================

    current_time = session_start

    # --------------------------------------------------------
    # EVENT 1 — SESSION START
    # --------------------------------------------------------

    event_rows.append({
        "event_id": event_id,
        "session_id": session_id,
        "customer_id": customer_id,
        "event_timestamp": current_time,
        "event_type": "session_start",
        "product_id": None,
        "page_name": landing_page,
        "device_type": device_type
    })

    event_id += 1


    # --------------------------------------------------------
    # Determine funnel behaviour
    # --------------------------------------------------------

    # Probability of viewing a product
    product_view_probability = {
        "Desktop": 0.78,
        "Mobile": 0.70,
        "Tablet": 0.73
    }

    if random.random() > product_view_probability[device_type]:
        continue


    # --------------------------------------------------------
    # EVENT 2 — PRODUCT VIEW
    # --------------------------------------------------------

    current_time += timedelta(
        seconds=random.randint(5, 60)
    )

    product_id = int(
        random.choice(
            products_df["product_id"].values
        )
    )

    event_rows.append({
        "event_id": event_id,
        "session_id": session_id,
        "customer_id": customer_id,
        "event_timestamp": current_time,
        "event_type": "product_view",
        "product_id": product_id,
        "page_name": "Product",
        "device_type": device_type
    })

    event_id += 1


    # --------------------------------------------------------
    # EVENT 3 — ADD TO CART
    # --------------------------------------------------------

    # Mobile slightly lower add-to-cart probability
    add_to_cart_probability = {
        "Desktop": 0.42,
        "Mobile": 0.34,
        "Tablet": 0.38
    }

    if random.random() > add_to_cart_probability[device_type]:
        continue


    current_time += timedelta(
        seconds=random.randint(10, 120)
    )

    event_rows.append({
        "event_id": event_id,
        "session_id": session_id,
        "customer_id": customer_id,
        "event_timestamp": current_time,
        "event_type": "add_to_cart",
        "product_id": product_id,
        "page_name": "Cart",
        "device_type": device_type
    })

    event_id += 1


    # --------------------------------------------------------
    # EVENT 4 — CHECKOUT START
    # --------------------------------------------------------

    checkout_probability = {
        "Desktop": 0.72,
        "Mobile": 0.62,
        "Tablet": 0.67
    }

    if random.random() > checkout_probability[device_type]:
        continue


    current_time += timedelta(
        seconds=random.randint(20, 180)
    )

    event_rows.append({
        "event_id": event_id,
        "session_id": session_id,
        "customer_id": customer_id,
        "event_timestamp": current_time,
        "event_type": "checkout_start",
        "product_id": product_id,
        "page_name": "Checkout",
        "device_type": device_type
    })

    event_id += 1


    # --------------------------------------------------------
    # EVENT 5 — PAYMENT ATTEMPT
    # --------------------------------------------------------

    payment_attempt_probability = {
        "Desktop": 0.88,
        "Mobile": 0.82,
        "Tablet": 0.85
    }

    if random.random() > payment_attempt_probability[device_type]:
        continue


    current_time += timedelta(
        seconds=random.randint(20, 180)
    )

    event_rows.append({
        "event_id": event_id,
        "session_id": session_id,
        "customer_id": customer_id,
        "event_timestamp": current_time,
        "event_type": "payment_attempt",
        "product_id": product_id,
        "page_name": "Payment",
        "device_type": device_type
    })

    event_id += 1


    # --------------------------------------------------------
    # EVENT 6 — PURCHASE
    # --------------------------------------------------------

    # Final conversion probability
    purchase_probability = {
        "Desktop": 0.82,
        "Mobile": 0.76,
        "Tablet": 0.79
    }

    if random.random() > purchase_probability[device_type]:
        continue


    current_time += timedelta(
        seconds=random.randint(10, 120)
    )

    event_rows.append({
        "event_id": event_id,
        "session_id": session_id,
        "customer_id": customer_id,
        "event_timestamp": current_time,
        "event_type": "purchase",
        "product_id": product_id,
        "page_name": "Confirmation",
        "device_type": device_type
    })

    event_id += 1


# ============================================================
# CREATE DATAFRAMES
# ============================================================

sessions_df = pd.DataFrame(session_rows)
events_df = pd.DataFrame(event_rows)


# ============================================================
# SAVE FILES
# ============================================================

sessions_df.to_csv(
    f"{OUTPUT_DIR}/sessions.csv",
    index=False
)

events_df.to_csv(
    f"{OUTPUT_DIR}/events.csv",
    index=False
)


# ============================================================
# QUALITY CHECKS
# ============================================================

print(
    f"Sessions generated: "
    f"{len(sessions_df):,}"
)

print(
    f"Events generated: "
    f"{len(events_df):,}"
)

print("\nEvent distribution:")

print(
    events_df["event_type"]
    .value_counts()
)

print("\nDevice distribution:")

print(
    sessions_df["device_type"]
    .value_counts()
)

print("\nAnonymous vs identified sessions:")

print(
    sessions_df["customer_id"]
    .isna()
    .value_counts()
)

# ============================================================
# SUMMARY
# ============================================================

print("\n========================================")
print("INITIAL DATA GENERATION COMPLETE")
print("========================================")

print(f"Customers:             {len(customers_df):,}")
print(f"Products:              {len(products_df):,}")
print(f"Marketing campaigns:   {len(campaigns_df):,}")

print("\nFiles created:")

for file in os.listdir(OUTPUT_DIR):
    print(f"  - {file}")