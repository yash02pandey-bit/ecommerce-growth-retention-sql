import os
import pandas as pd


DATA_DIR = "data/raw"


def check_file(filename, required_columns):
    path = os.path.join(DATA_DIR, filename)

    print(f"\n{'=' * 60}")
    print(f"VALIDATING: {filename}")
    print(f"{'=' * 60}")

    df = pd.read_csv(path)

    print(f"Rows: {len(df):,}")
    print(f"Columns: {len(df.columns)}")

    missing_columns = [
        col for col in required_columns
        if col not in df.columns
    ]

    if missing_columns:
        print("❌ Missing columns:", missing_columns)
    else:
        print("✅ Required columns present")

    print("\nNull values:")
    print(df.isnull().sum())

    return df


# ============================================================
# LOAD DATA
# ============================================================

customers = check_file(
    "customers.csv",
    [
        "customer_id",
        "first_name",
        "last_name",
        "email",
        "gender",
        "date_of_birth",
        "city",
        "country",
        "signup_date",
        "acquisition_channel",
        "customer_status"
    ]
)

products = check_file(
    "products.csv",
    [
        "product_id",
        "product_name",
        "category",
        "subcategory",
        "brand",
        "unit_price",
        "cost_price",
        "launch_date",
        "product_status"
    ]
)

orders = check_file(
    "orders.csv",
    [
        "order_id",
        "customer_id",
        "order_timestamp",
        "order_status",
        "sales_channel",
        "shipping_city",
        "shipping_country",
        "discount_amount",
        "shipping_fee",
        "order_total"
    ]
)

order_items = check_file(
    "order_items.csv",
    [
        "order_item_id",
        "order_id",
        "product_id",
        "quantity",
        "unit_price",
        "discount_amount",
        "item_total"
    ]
)

payments = check_file(
    "payments.csv",
    [
        "payment_id",
        "order_id",
        "payment_timestamp",
        "payment_method",
        "payment_status",
        "amount",
        "failure_reason"
    ]
)

returns = check_file(
    "returns.csv",
    [
        "return_id",
        "order_item_id",
        "return_date",
        "quantity_returned",
        "return_reason",
        "refund_amount",
        "return_status"
    ]
)

sessions = check_file(
    "sessions.csv",
    [
        "session_id",
        "customer_id",
        "session_start",
        "session_end",
        "device_type",
        "acquisition_channel",
        "landing_page"
    ]
)

events = check_file(
    "events.csv",
    [
        "event_id",
        "session_id",
        "customer_id",
        "event_timestamp",
        "event_type",
        "product_id",
        "page_name",
        "device_type"
    ]
)

campaigns = check_file(
    "marketing_campaigns.csv",
    [
        "campaign_id",
        "campaign_name",
        "acquisition_channel",
        "campaign_start",
        "campaign_end",
        "campaign_budget",
        "campaign_spend"
    ]
)


# ============================================================
# PRIMARY KEY CHECKS
# ============================================================

print("\n\n" + "=" * 60)
print("PRIMARY KEY VALIDATION")
print("=" * 60)

primary_keys = {
    "customers": (customers, "customer_id"),
    "products": (products, "product_id"),
    "orders": (orders, "order_id"),
    "order_items": (order_items, "order_item_id"),
    "payments": (payments, "payment_id"),
    "returns": (returns, "return_id"),
    "sessions": (sessions, "session_id"),
    "events": (events, "event_id"),
    "campaigns": (campaigns, "campaign_id")
}

for table_name, (df, column) in primary_keys.items():

    duplicate_count = df[column].duplicated().sum()

    if duplicate_count == 0:
        print(f"✅ {table_name}: no duplicate {column}")
    else:
        print(
            f"❌ {table_name}: "
            f"{duplicate_count:,} duplicate {column} values"
        )


# ============================================================
# FOREIGN KEY VALIDATION
# ============================================================

print("\n\n" + "=" * 60)
print("FOREIGN KEY VALIDATION")
print("=" * 60)


def check_foreign_key(
    child_df,
    child_column,
    parent_df,
    parent_column,
    relationship_name
):

    invalid = (
        ~child_df[child_column]
        .isin(parent_df[parent_column])
    )

    # NULL foreign keys are allowed in our schema
    invalid = invalid & child_df[child_column].notna()

    invalid_count = invalid.sum()

    if invalid_count == 0:
        print(f"✅ {relationship_name}")
    else:
        print(
            f"❌ {relationship_name}: "
            f"{invalid_count:,} invalid references"
        )


check_foreign_key(
    orders,
    "customer_id",
    customers,
    "customer_id",
    "orders → customers"
)

check_foreign_key(
    order_items,
    "order_id",
    orders,
    "order_id",
    "order_items → orders"
)

check_foreign_key(
    order_items,
    "product_id",
    products,
    "product_id",
    "order_items → products"
)

check_foreign_key(
    payments,
    "order_id",
    orders,
    "order_id",
    "payments → orders"
)

check_foreign_key(
    returns,
    "order_item_id",
    order_items,
    "order_item_id",
    "returns → order_items"
)

check_foreign_key(
    sessions,
    "customer_id",
    customers,
    "customer_id",
    "sessions → customers"
)

check_foreign_key(
    events,
    "session_id",
    sessions,
    "session_id",
    "events → sessions"
)

check_foreign_key(
    events,
    "customer_id",
    customers,
    "customer_id",
    "events → customers"
)

check_foreign_key(
    events,
    "product_id",
    products,
    "product_id",
    "events → products"
)


# ============================================================
# BUSINESS LOGIC CHECKS
# ============================================================

print("\n\n" + "=" * 60)
print("BUSINESS LOGIC VALIDATION")
print("=" * 60)


# Order total should be positive
negative_orders = (
    orders["order_total"] <= 0
).sum()

print(
    "Orders with non-positive total:",
    negative_orders
)


# Quantity should be positive
invalid_quantities = (
    order_items["quantity"] <= 0
).sum()

print(
    "Order items with invalid quantity:",
    invalid_quantities
)


# Return quantity cannot exceed original quantity
return_check = returns.merge(
    order_items[
        [
            "order_item_id",
            "quantity"
        ]
    ],
    on="order_item_id",
    how="left"
)

invalid_returns = (
    return_check["quantity_returned"] >
    return_check["quantity"]
).sum()

print(
    "Returns exceeding original quantity:",
    invalid_returns
)


# Product cost should be below selling price
invalid_product_prices = (
    products["cost_price"] >
    products["unit_price"]
).sum()

print(
    "Products where cost > selling price:",
    invalid_product_prices
)


# Campaign spend should normally not exceed budget
overspend_campaigns = (
    campaigns["campaign_spend"] >
    campaigns["campaign_budget"]
).sum()

print(
    "Campaigns exceeding budget:",
    overspend_campaigns
)


# ============================================================
# EVENT FUNNEL CHECK
# ============================================================

print("\n\n" + "=" * 60)
print("EVENT FUNNEL VALIDATION")
print("=" * 60)

event_counts = (
    events["event_type"]
    .value_counts()
)

for event_type, count in event_counts.items():

    print(
        f"{event_type:20s} "
        f"{count:>10,}"
    )


# ============================================================
# FINAL SUMMARY
# ============================================================

print("\n\n" + "=" * 60)
print("VALIDATION COMPLETE")
print("=" * 60)

print("All generated datasets have been inspected.")