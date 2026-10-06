-- ============================================================
-- NovaCart E-Commerce Analytics
-- Data Loading Script
-- ============================================================

-- Load customers first because other tables depend on it
COPY customers
FROM '/tmp/raw/customers.csv'
WITH (
    FORMAT CSV,
    HEADER TRUE
);

-- Products
COPY products
FROM '/tmp/raw/products.csv'
WITH (
    FORMAT CSV,
    HEADER TRUE
);

-- Marketing campaigns
COPY marketing_campaigns
FROM '/tmp/raw/marketing_campaigns.csv'
WITH (
    FORMAT CSV,
    HEADER TRUE
);

-- Orders depend on customers
COPY orders
FROM '/tmp/raw/orders.csv'
WITH (
    FORMAT CSV,
    HEADER TRUE
);

-- Order items depend on orders and products
COPY order_items
FROM '/tmp/raw/order_items.csv'
WITH (
    FORMAT CSV,
    HEADER TRUE
);

-- Payments depend on orders
COPY payments
FROM '/tmp/raw/payments.csv'
WITH (
    FORMAT CSV,
    HEADER TRUE
);

-- Returns depend on order items
COPY returns
FROM '/tmp/raw/returns.csv'
WITH (
    FORMAT CSV,
    HEADER TRUE
);

-- Sessions depend on customers
COPY sessions
FROM '/tmp/raw/sessions.csv'
WITH (
    FORMAT CSV,
    HEADER TRUE
);

-- Events depend on sessions, customers and products
COPY events
FROM '/tmp/raw/events.csv'
WITH (
    FORMAT CSV,
    HEADER TRUE
);