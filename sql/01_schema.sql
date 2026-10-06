-- ============================================================
-- PROJECT: E-Commerce Growth, Conversion & Customer Retention
-- DATABASE: ecommerce_analytics
-- FILE: 01_schema.sql
-- PURPOSE: Create the analytical database schema
-- ============================================================


-- ============================================================
-- 1. CUSTOMERS
-- Grain: 1 row = 1 customer
-- ============================================================

CREATE TABLE IF NOT EXISTS customers (
    customer_id BIGINT PRIMARY KEY,
    first_name VARCHAR(50) NOT NULL,
    last_name VARCHAR(50),
    email VARCHAR(150) NOT NULL,
    gender VARCHAR(20),
    date_of_birth DATE,
    city VARCHAR(100),
    country VARCHAR(50) NOT NULL,
    signup_date TIMESTAMP NOT NULL,
    acquisition_channel VARCHAR(50),
    customer_status VARCHAR(20) NOT NULL
);


-- ============================================================
-- 2. PRODUCTS
-- Grain: 1 row = 1 product
-- ============================================================

CREATE TABLE IF NOT EXISTS products (
    product_id BIGINT PRIMARY KEY,
    product_name VARCHAR(150) NOT NULL,
    category VARCHAR(50) NOT NULL,
    subcategory VARCHAR(75),
    brand VARCHAR(100),
    unit_price NUMERIC(12,2) NOT NULL,
    cost_price NUMERIC(12,2) NOT NULL,
    launch_date DATE NOT NULL,
    product_status VARCHAR(20) NOT NULL
);


-- ============================================================
-- 3. ORDERS
-- Grain: 1 row = 1 order
-- ============================================================

CREATE TABLE IF NOT EXISTS orders (
    order_id BIGINT PRIMARY KEY,
    customer_id BIGINT NOT NULL,
    order_timestamp TIMESTAMP NOT NULL,
    order_status VARCHAR(30) NOT NULL,
    sales_channel VARCHAR(20) NOT NULL,
    shipping_city VARCHAR(100),
    shipping_country VARCHAR(50) NOT NULL,
    discount_amount NUMERIC(12,2),
    shipping_fee NUMERIC(12,2),
    order_total NUMERIC(12,2) NOT NULL,

    CONSTRAINT fk_orders_customer
        FOREIGN KEY (customer_id)
        REFERENCES customers(customer_id)
);


-- ============================================================
-- 4. ORDER ITEMS
-- Grain: 1 row = 1 product line within an order
-- ============================================================

CREATE TABLE IF NOT EXISTS order_items (
    order_item_id BIGINT PRIMARY KEY,
    order_id BIGINT NOT NULL,
    product_id BIGINT NOT NULL,
    quantity INTEGER NOT NULL,
    unit_price NUMERIC(12,2) NOT NULL,
    discount_amount NUMERIC(12,2),
    item_total NUMERIC(12,2) NOT NULL,

    CONSTRAINT fk_order_items_order
        FOREIGN KEY (order_id)
        REFERENCES orders(order_id),

    CONSTRAINT fk_order_items_product
        FOREIGN KEY (product_id)
        REFERENCES products(product_id)
);


-- ============================================================
-- 5. PAYMENTS
-- Grain: 1 row = 1 payment attempt
-- ============================================================

CREATE TABLE IF NOT EXISTS payments (
    payment_id BIGINT PRIMARY KEY,
    order_id BIGINT NOT NULL,
    payment_timestamp TIMESTAMP NOT NULL,
    payment_method VARCHAR(30) NOT NULL,
    payment_status VARCHAR(20) NOT NULL,
    amount NUMERIC(12,2) NOT NULL,
    failure_reason VARCHAR(100),

    CONSTRAINT fk_payments_order
        FOREIGN KEY (order_id)
        REFERENCES orders(order_id)
);


-- ============================================================
-- 6. RETURNS
-- Grain: 1 row = 1 returned order item
-- ============================================================

CREATE TABLE IF NOT EXISTS returns (
    return_id BIGINT PRIMARY KEY,
    order_item_id BIGINT NOT NULL,
    return_date TIMESTAMP NOT NULL,
    quantity_returned INTEGER NOT NULL,
    return_reason VARCHAR(100),
    refund_amount NUMERIC(12,2) NOT NULL,
    return_status VARCHAR(30) NOT NULL,

    CONSTRAINT fk_returns_order_item
        FOREIGN KEY (order_item_id)
        REFERENCES order_items(order_item_id)
);


-- ============================================================
-- 7. SESSIONS
-- Grain: 1 row = 1 customer/anonymous session
-- ============================================================

CREATE TABLE IF NOT EXISTS sessions (
    session_id BIGINT PRIMARY KEY,
    customer_id BIGINT,
    session_start TIMESTAMP NOT NULL,
    session_end TIMESTAMP,
    device_type VARCHAR(20) NOT NULL,
    acquisition_channel VARCHAR(50),
    landing_page VARCHAR(150),

    CONSTRAINT fk_sessions_customer
        FOREIGN KEY (customer_id)
        REFERENCES customers(customer_id)
);


-- ============================================================
-- 8. EVENTS
-- Grain: 1 row = 1 user event
-- ============================================================

CREATE TABLE IF NOT EXISTS events (
    event_id BIGINT PRIMARY KEY,
    session_id BIGINT NOT NULL,
    customer_id BIGINT,
    event_timestamp TIMESTAMP NOT NULL,
    event_type VARCHAR(50) NOT NULL,
    product_id BIGINT,
    page_name VARCHAR(100),
    device_type VARCHAR(20) NOT NULL,

    CONSTRAINT fk_events_session
        FOREIGN KEY (session_id)
        REFERENCES sessions(session_id),

    CONSTRAINT fk_events_customer
        FOREIGN KEY (customer_id)
        REFERENCES customers(customer_id),

    CONSTRAINT fk_events_product
        FOREIGN KEY (product_id)
        REFERENCES products(product_id)
);


-- ============================================================
-- 9. MARKETING CAMPAIGNS
-- Grain: 1 row = 1 campaign
-- ============================================================

CREATE TABLE IF NOT EXISTS marketing_campaigns (
    campaign_id BIGINT PRIMARY KEY,
    campaign_name VARCHAR(150) NOT NULL,
    acquisition_channel VARCHAR(50) NOT NULL,
    campaign_start DATE NOT NULL,
    campaign_end DATE NOT NULL,
    campaign_budget NUMERIC(14,2),
    campaign_spend NUMERIC(14,2)
);


-- ============================================================
-- SCHEMA COMPLETE
-- ============================================================

SELECT table_name
FROM information_schema.tables
WHERE table_schema = 'public'
ORDER BY table_name;

SELECT
    tc.table_name,
    kcu.column_name,
    ccu.table_name AS foreign_table_name,
    ccu.column_name AS foreign_column_name
FROM information_schema.table_constraints AS tc
JOIN information_schema.key_column_usage AS kcu
    ON tc.constraint_name = kcu.constraint_name
JOIN information_schema.constraint_column_usage AS ccu
    ON ccu.constraint_name = tc.constraint_name
WHERE tc.constraint_type = 'FOREIGN KEY'
ORDER BY tc.table_name;