--SECTION 0. DATABASE BOOTSTRAP
DROP DATABASE IF EXISTS household_appliances_store_db;
CREATE DATABASE household_appliances_store_db;


--SECTION 1. SCHEMA CLEANUP
CREATE SCHEMA IF NOT EXISTS household_store;

DROP VIEW IF EXISTS household_store.v_latest_quarter_sales_analytics;

DROP FUNCTION IF EXISTS household_store.fn_update_product_attribute(INT, TEXT, TEXT);
DROP FUNCTION IF EXISTS household_store.fn_add_sales_transaction(
    TEXT, TEXT, TIMESTAMP, TEXT, TEXT, INT, NUMERIC, TEXT
);

DROP TABLE IF EXISTS household_store.order_item CASCADE;
DROP TABLE IF EXISTS household_store.sales_order CASCADE;
DROP TABLE IF EXISTS household_store.product CASCADE;
DROP TABLE IF EXISTS household_store.customer CASCADE;
DROP TABLE IF EXISTS household_store.supplier CASCADE;
DROP TABLE IF EXISTS household_store.category CASCADE;

-- SECTION 2. TABLES (3NF)
CREATE TABLE household_store.category (
    category_id         INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    category_name       VARCHAR(60) NOT NULL,
    category_desc       TEXT,
    created_at          TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_category_name UNIQUE (category_name)
);

CREATE TABLE household_store.supplier (
    supplier_id         INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    supplier_name       VARCHAR(120) NOT NULL,
    contact_person      VARCHAR(120) NOT NULL,
    phone               VARCHAR(25) NOT NULL,
    email               VARCHAR(150) NOT NULL,
    city                VARCHAR(80) NOT NULL,
    supplier_status     VARCHAR(20) NOT NULL DEFAULT 'ACTIVE',
    created_at          TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_supplier_name UNIQUE (supplier_name),
    CONSTRAINT uq_supplier_email UNIQUE (email)
);


CREATE TABLE household_store.customer (
    customer_id         INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    first_name          VARCHAR(60) NOT NULL,
    last_name           VARCHAR(60) NOT NULL,
    email               VARCHAR(150) NOT NULL,
    phone               VARCHAR(25) NOT NULL,
    city                VARCHAR(80) NOT NULL,
    loyalty_level       VARCHAR(20) NOT NULL DEFAULT 'STANDARD',
    registered_at       TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_customer_email UNIQUE (email)
);

CREATE TABLE household_store.product (
    product_id          INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    category_id         INT NOT NULL REFERENCES household_store.category(category_id),
    supplier_id         INT NOT NULL REFERENCES household_store.supplier(supplier_id),
    sku                 VARCHAR(40) NOT NULL,
    product_name        VARCHAR(120) NOT NULL,
    brand               VARCHAR(80) NOT NULL,
    model               VARCHAR(80) NOT NULL,
    unit_price          NUMERIC(10,2) NOT NULL,
    stock_quantity      INT NOT NULL DEFAULT 0,
    warranty_months     INT NOT NULL DEFAULT 12,
    reorder_level       INT NOT NULL DEFAULT 5,
    active_flag         BOOLEAN NOT NULL DEFAULT TRUE,
    created_at          TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    stock_value         NUMERIC(12,2) GENERATED ALWAYS AS ((stock_quantity * unit_price)::NUMERIC(12,2)) STORED,
    CONSTRAINT uq_product_sku UNIQUE (sku),
    CONSTRAINT uq_product_brand_model UNIQUE (brand, model)
);


CREATE TABLE household_store.sales_order (
    order_id            INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_number        VARCHAR(30) NOT NULL,
    customer_id         INT NOT NULL REFERENCES household_store.customer(customer_id),
    order_date          TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    order_status        VARCHAR(20) NOT NULL DEFAULT 'PENDING',
    payment_method      VARCHAR(20) NOT NULL,
    notes               TEXT,
    created_at          TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_order_number UNIQUE (order_number)
);


CREATE TABLE household_store.order_item (
    order_item_id       INT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id            INT NOT NULL REFERENCES household_store.sales_order(order_id) ON DELETE CASCADE,
    product_id          INT NOT NULL REFERENCES household_store.product(product_id),
    quantity            INT NOT NULL,
    unit_price          NUMERIC(10,2) NOT NULL,
    discount_percent    NUMERIC(5,2) NOT NULL DEFAULT 0.00,
    line_total          NUMERIC(12,2) GENERATED ALWAYS AS (
                            ROUND((quantity * unit_price * (1 - discount_percent / 100.0))::numeric, 2)
                        ) STORED,
    created_at          TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT uq_order_product UNIQUE (order_id, product_id)
);

--SECTION 3. CHECK CONSTRAINTS ADDED VIA ALTER TABLE

ALTER TABLE household_store.supplier
    ADD CONSTRAINT chk_supplier_status_allowed
    CHECK (supplier_status IN ('ACTIVE', 'INACTIVE'));

ALTER TABLE household_store.customer
    ADD CONSTRAINT chk_customer_loyalty_level_allowed
    CHECK (loyalty_level IN ('STANDARD', 'SILVER', 'GOLD', 'PLATINUM'));

ALTER TABLE household_store.product
    ADD CONSTRAINT chk_product_unit_price_positive
    CHECK (unit_price > 0);

ALTER TABLE household_store.product
    ADD CONSTRAINT chk_product_stock_quantity_nonnegative
    CHECK (stock_quantity >= 0);

ALTER TABLE household_store.product
    ADD CONSTRAINT chk_product_warranty_nonnegative
    CHECK (warranty_months >= 0);

ALTER TABLE household_store.product
    ADD CONSTRAINT chk_product_reorder_level_nonnegative
    CHECK (reorder_level >= 0);

ALTER TABLE household_store.sales_order
    ADD CONSTRAINT chk_sales_order_date_after_2026_01_01
    CHECK (order_date > TIMESTAMP '2026-01-01 00:00:00');

ALTER TABLE household_store.sales_order
    ADD CONSTRAINT chk_sales_order_status_allowed
    CHECK (order_status IN ('PENDING', 'PAID', 'SHIPPED', 'DELIVERED', 'CANCELLED'));

ALTER TABLE household_store.sales_order
    ADD CONSTRAINT chk_sales_order_payment_method_allowed
    CHECK (payment_method IN ('CARD', 'CASH', 'BANK_TRANSFER', 'ONLINE'));

ALTER TABLE household_store.order_item
    ADD CONSTRAINT chk_order_item_quantity_positive
    CHECK (quantity > 0);

ALTER TABLE household_store.order_item
    ADD CONSTRAINT chk_order_item_unit_price_positive
    CHECK (unit_price > 0);

ALTER TABLE household_store.order_item
    ADD CONSTRAINT chk_order_item_discount_range
    CHECK (discount_percent >= 0 AND discount_percent <= 100);

--SECTION 4. SAMPLE DATA

INSERT INTO household_store.category (category_name, category_desc)
VALUES
    ('Refrigerators', 'Cooling and food preservation appliances'),
    ('Washing Machines', 'Laundry appliances for home use'),
    ('Microwaves', 'Compact kitchen heating appliances'),
    ('Vacuum Cleaners', 'Cleaning appliances for floor and surface care'),
    ('Air Conditioners', 'Home climate control appliances'),
    ('Dishwashers', 'Automatic dish cleaning appliances');

INSERT INTO household_store.supplier (supplier_name, contact_person, phone, email, city, supplier_status)
VALUES
    ('ElectroSupply LLC', 'Olena Koval', '+380441110001', 'sales@electrosupply.ua', 'Kyiv', 'ACTIVE'),
    ('HomeTech Distribution', 'Ivan Petrenko', '+380441110002', 'contact@hometech.ua', 'Lviv', 'ACTIVE'),
    ('Nordic Appliances Hub', 'Maksym Bondar', '+380441110003', 'orders@nordichub.ua', 'Odesa', 'ACTIVE'),
    ('SmartRetail Partners', 'Iryna Shevchenko', '+380441110004', 'procurement@smartretail.ua', 'Dnipro', 'ACTIVE'),
    ('Urban Device Trade', 'Andrii Melnyk', '+380441110005', 'team@urbandevice.ua', 'Kharkiv', 'ACTIVE'),
    ('Prime Domestic Goods', 'Svitlana Hrytsenko', '+380441110006', 'hello@primedomestic.ua', 'Kyiv', 'ACTIVE');

INSERT INTO household_store.customer (first_name, last_name, email, phone, city, loyalty_level, registered_at)
VALUES
    ('Olha', 'Marchenko', 'olha.marchenko@gmail.com', '+380671000001', 'Kyiv', 'GOLD', CURRENT_TIMESTAMP - INTERVAL '88 days'),
    ('Taras', 'Klymenko', 'taras.klymenko@gmail.com', '+380671000002', 'Lviv', 'STANDARD', CURRENT_TIMESTAMP - INTERVAL '79 days'),
    ('Iryna', 'Bondarenko', 'iryna.bondarenko@gmail.com', '+380671000003', 'Odesa', 'SILVER', CURRENT_TIMESTAMP - INTERVAL '66 days'),
    ('Dmytro', 'Shevchuk', 'dmytro.shevchuk@gmail.com', '+380671000004', 'Dnipro', 'PLATINUM', CURRENT_TIMESTAMP - INTERVAL '53 days'),
    ('Kateryna', 'Hnatiuk', 'kateryna.hnatiuk@gmail.com', '+380671000005', 'Kharkiv', 'STANDARD', CURRENT_TIMESTAMP - INTERVAL '41 days'),
    ('Maksym', 'Tymoshenko', 'maksym.tymoshenko@gmail.com', '+380671000006', 'Kyiv', 'SILVER', CURRENT_TIMESTAMP - INTERVAL '29 days');

INSERT INTO household_store.product (
    category_id, supplier_id, sku, product_name, brand, model,
    unit_price, stock_quantity, warranty_months, reorder_level, active_flag, created_at
)
VALUES
    (
        (SELECT category_id FROM household_store.category WHERE category_name = 'Refrigerators'),
        (SELECT supplier_id FROM household_store.supplier WHERE supplier_name = 'ElectroSupply LLC'),
        'RF-SAM-001', 'Double Door Refrigerator', 'Samsung', 'RB34T600FSA',
        27999.00, 12, 36, 3, TRUE, CURRENT_TIMESTAMP - INTERVAL '85 days'
    ),
    (
        (SELECT category_id FROM household_store.category WHERE category_name = 'Washing Machines'),
        (SELECT supplier_id FROM household_store.supplier WHERE supplier_name = 'HomeTech Distribution'),
        'WM-LG-001', 'Front Load Washing Machine', 'LG', 'F2V5GS0W',
        21499.00, 10, 24, 2, TRUE, CURRENT_TIMESTAMP - INTERVAL '81 days'
    ),
    (
        (SELECT category_id FROM household_store.category WHERE category_name = 'Microwaves'),
        (SELECT supplier_id FROM household_store.supplier WHERE supplier_name = 'Nordic Appliances Hub'),
        'MW-PHI-001', 'Digital Microwave Oven', 'Philips', 'HD9252',
        4999.00, 22, 12, 5, TRUE, CURRENT_TIMESTAMP - INTERVAL '74 days'
    ),
    (
        (SELECT category_id FROM household_store.category WHERE category_name = 'Vacuum Cleaners'),
        (SELECT supplier_id FROM household_store.supplier WHERE supplier_name = 'SmartRetail Partners'),
        'VC-BOS-001', 'Bagless Vacuum Cleaner', 'Bosch', 'BGS05A220',
        6599.00, 18, 24, 4, TRUE, CURRENT_TIMESTAMP - INTERVAL '62 days'
    ),
    (
        (SELECT category_id FROM household_store.category WHERE category_name = 'Air Conditioners'),
        (SELECT supplier_id FROM household_store.supplier WHERE supplier_name = 'Urban Device Trade'),
        'AC-GRE-001', 'Inverter Air Conditioner', 'Gree', 'GWH12QC',
        18999.00, 8, 24, 2, TRUE, CURRENT_TIMESTAMP - INTERVAL '49 days'
    ),
    (
        (SELECT category_id FROM household_store.category WHERE category_name = 'Dishwashers'),
        (SELECT supplier_id FROM household_store.supplier WHERE supplier_name = 'Prime Domestic Goods'),
        'DW-BEK-001', 'Freestanding Dishwasher', 'Beko', 'DFN28424X',
        17499.00, 7, 24, 2, TRUE, CURRENT_TIMESTAMP - INTERVAL '35 days'
    );

INSERT INTO household_store.sales_order (order_number, customer_id, order_date, order_status, payment_method, notes)
VALUES
    (
        'SO-' || TO_CHAR(CURRENT_DATE - INTERVAL '80 days', 'YYYYMMDD') || '-001',
        (SELECT customer_id FROM household_store.customer WHERE email = 'olha.marchenko@gmail.com'),
        CURRENT_TIMESTAMP - INTERVAL '80 days',
        'DELIVERED', 'CARD', 'Home delivery completed'
    ),
    (
        'SO-' || TO_CHAR(CURRENT_DATE - INTERVAL '68 days', 'YYYYMMDD') || '-001',
        (SELECT customer_id FROM household_store.customer WHERE email = 'taras.klymenko@gmail.com'),
        CURRENT_TIMESTAMP - INTERVAL '68 days',
        'DELIVERED', 'ONLINE', 'Paid during website checkout'
    ),
    (
        'SO-' || TO_CHAR(CURRENT_DATE - INTERVAL '54 days', 'YYYYMMDD') || '-001',
        (SELECT customer_id FROM household_store.customer WHERE email = 'iryna.bondarenko@gmail.com'),
        CURRENT_TIMESTAMP - INTERVAL '54 days',
        'SHIPPED', 'BANK_TRANSFER', 'Awaiting final delivery confirmation'
    ),
    (
        'SO-' || TO_CHAR(CURRENT_DATE - INTERVAL '42 days', 'YYYYMMDD') || '-001',
        (SELECT customer_id FROM household_store.customer WHERE email = 'dmytro.shevchuk@gmail.com'),
        CURRENT_TIMESTAMP - INTERVAL '42 days',
        'PAID', 'CARD', 'Warehouse pickup scheduled'
    ),
    (
        'SO-' || TO_CHAR(CURRENT_DATE - INTERVAL '26 days', 'YYYYMMDD') || '-001',
        (SELECT customer_id FROM household_store.customer WHERE email = 'kateryna.hnatiuk@gmail.com'),
        CURRENT_TIMESTAMP - INTERVAL '26 days',
        'DELIVERED', 'CASH', 'Customer purchased in store'
    ),
    (
        'SO-' || TO_CHAR(CURRENT_DATE - INTERVAL '12 days', 'YYYYMMDD') || '-001',
        (SELECT customer_id FROM household_store.customer WHERE email = 'maksym.tymoshenko@gmail.com'),
        CURRENT_TIMESTAMP - INTERVAL '12 days',
        'PENDING', 'ONLINE', 'Order created, waiting for shipment'
    );


INSERT INTO household_store.order_item (order_id, product_id, quantity, unit_price, discount_percent)
VALUES
    (
        (SELECT order_id FROM household_store.sales_order WHERE order_number = 'SO-' || TO_CHAR(CURRENT_DATE - INTERVAL '80 days', 'YYYYMMDD') || '-001'),
        (SELECT product_id FROM household_store.product WHERE sku = 'RF-SAM-001'),
        1,
        (SELECT unit_price FROM household_store.product WHERE sku = 'RF-SAM-001'),
        5.00
    ),
    (
        (SELECT order_id FROM household_store.sales_order WHERE order_number = 'SO-' || TO_CHAR(CURRENT_DATE - INTERVAL '68 days', 'YYYYMMDD') || '-001'),
        (SELECT product_id FROM household_store.product WHERE sku = 'WM-LG-001'),
        1,
        (SELECT unit_price FROM household_store.product WHERE sku = 'WM-LG-001'),
        3.00
    ),
    (
        (SELECT order_id FROM household_store.sales_order WHERE order_number = 'SO-' || TO_CHAR(CURRENT_DATE - INTERVAL '54 days', 'YYYYMMDD') || '-001'),
        (SELECT product_id FROM household_store.product WHERE sku = 'MW-PHI-001'),
        2,
        (SELECT unit_price FROM household_store.product WHERE sku = 'MW-PHI-001'),
        0.00
    ),
    (
        (SELECT order_id FROM household_store.sales_order WHERE order_number = 'SO-' || TO_CHAR(CURRENT_DATE - INTERVAL '42 days', 'YYYYMMDD') || '-001'),
        (SELECT product_id FROM household_store.product WHERE sku = 'VC-BOS-001'),
        1,
        (SELECT unit_price FROM household_store.product WHERE sku = 'VC-BOS-001'),
        10.00
    ),
    (
        (SELECT order_id FROM household_store.sales_order WHERE order_number = 'SO-' || TO_CHAR(CURRENT_DATE - INTERVAL '26 days', 'YYYYMMDD') || '-001'),
        (SELECT product_id FROM household_store.product WHERE sku = 'AC-GRE-001'),
        1,
        (SELECT unit_price FROM household_store.product WHERE sku = 'AC-GRE-001'),
        4.50
    ),
    (
        (SELECT order_id FROM household_store.sales_order WHERE order_number = 'SO-' || TO_CHAR(CURRENT_DATE - INTERVAL '12 days', 'YYYYMMDD') || '-001'),
        (SELECT product_id FROM household_store.product WHERE sku = 'DW-BEK-001'),
        1,
        (SELECT unit_price FROM household_store.product WHERE sku = 'DW-BEK-001'),
        2.50
    );

-- SECTION 5. FUNCTIONS

-- 5.1 Generic update function for selected product columns.

CREATE OR REPLACE FUNCTION household_store.update_product_static(
    p_product_id INT,
    p_column_name TEXT,
    p_new_value TEXT
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
BEGIN
    IF p_column_name = 'unit_price' THEN
        UPDATE household_store.product
        SET unit_price = p_new_value::NUMERIC
        WHERE product_id = p_product_id;

    ELSIF p_column_name = 'stock_quantity' THEN
        UPDATE household_store.product
        SET stock_quantity = p_new_value::INT
        WHERE product_id = p_product_id;

    ELSIF p_column_name = 'warranty_months' THEN
        UPDATE household_store.product
        SET warranty_months = p_new_value::INT
        WHERE product_id = p_product_id;

    ELSIF p_column_name = 'reorder_level' THEN
        UPDATE household_store.product
        SET reorder_level = p_new_value::INT
        WHERE product_id = p_product_id;

    ELSIF p_column_name = 'active_flag' THEN
        UPDATE household_store.product
        SET active_flag = p_new_value::BOOLEAN
        WHERE product_id = p_product_id;

    ELSIF p_column_name = 'product_name' THEN
        UPDATE household_store.product
        SET product_name = p_new_value
        WHERE product_id = p_product_id;

    ELSIF p_column_name = 'brand' THEN
        UPDATE household_store.product
        SET brand = p_new_value
        WHERE product_id = p_product_id;

    ELSIF p_column_name = 'model' THEN
        UPDATE household_store.product
        SET model = p_new_value
        WHERE product_id = p_product_id;

    ELSE
        RAISE EXCEPTION 'Column "%" is not allowed.', p_column_name;
    END IF;

    -- check if row exists
    IF NOT FOUND THEN
        RAISE EXCEPTION 'Product with ID % not found.', p_product_id;
    END IF;

END;
$$;


-- 5.2 Function that adds a new sales transaction.

CREATE OR REPLACE FUNCTION household_store.fn_add_sales_transaction(
    p_customer_email      TEXT,
    p_product_sku         TEXT,
    p_order_date          TIMESTAMP,
    p_payment_method      TEXT,
    p_order_status        TEXT,
    p_quantity            INT,
    p_discount_percent    NUMERIC,
    p_notes               TEXT DEFAULT NULL
)
RETURNS VOID
LANGUAGE plpgsql
AS $$
DECLARE
    v_customer_id   INT;
    v_product_id    INT;
    v_unit_price    NUMERIC(10,2);
    v_stock         INT;
    v_order_id      INT;
    v_order_number  TEXT;
BEGIN
    SELECT customer_id
    INTO v_customer_id
    FROM household_store.customer
    WHERE email = p_customer_email;

    IF v_customer_id IS NULL THEN
        RAISE EXCEPTION 'Customer with email % was not found.', p_customer_email;
    END IF;

    SELECT product_id, unit_price, stock_quantity
    INTO v_product_id, v_unit_price, v_stock
    FROM household_store.product
    WHERE sku = p_product_sku;

    IF v_product_id IS NULL THEN
        RAISE EXCEPTION 'Product with SKU % was not found.', p_product_sku;
    END IF;

    IF p_quantity <= 0 THEN
        RAISE EXCEPTION 'Quantity must be greater than zero.';
    END IF;

    IF p_discount_percent < 0 OR p_discount_percent > 100 THEN
        RAISE EXCEPTION 'Discount percent must be between 0 and 100.';
    END IF;

    IF v_stock < p_quantity THEN
        RAISE EXCEPTION 'Not enough stock for SKU %. Available: %, requested: %.',
            p_product_sku, v_stock, p_quantity;
    END IF;

    v_order_number := 'SO-' || TO_CHAR(COALESCE(p_order_date, CURRENT_TIMESTAMP), 'YYYYMMDDHH24MISS');

    INSERT INTO household_store.sales_order (
        order_number, customer_id, order_date, order_status, payment_method, notes
    )
    VALUES (
        v_order_number, v_customer_id, COALESCE(p_order_date, CURRENT_TIMESTAMP),
        p_order_status, p_payment_method, p_notes
    )
    RETURNING order_id INTO v_order_id;

    INSERT INTO household_store.order_item (
        order_id, product_id, quantity, unit_price, discount_percent
    )
    VALUES (
        v_order_id, v_product_id, p_quantity, v_unit_price, p_discount_percent
    );

    UPDATE household_store.product
    SET stock_quantity = stock_quantity - p_quantity
    WHERE product_id = v_product_id;

    RAISE NOTICE 'Sales transaction added successfully. Order number: %', v_order_number;
END;
$$;

--SECTION 6. ANALYTICS VIEW FOR THE MOST RECENTLY ADDED QUARTER

CREATE OR REPLACE VIEW household_store.v_latest_quarter_sales_analytics AS
WITH latest_quarter AS (
    SELECT date_trunc('quarter', MAX(order_date)) AS quarter_start
    FROM household_store.sales_order
)
SELECT
    TO_CHAR(lq.quarter_start, 'YYYY') || ' Q' ||
        EXTRACT(QUARTER FROM lq.quarter_start)::INT AS sales_quarter,
    c.category_name,
    COUNT(DISTINCT so.order_number) AS total_orders,
    COUNT(DISTINCT cu.email) AS unique_customers,
    SUM(oi.quantity) AS units_sold,
    ROUND(SUM(oi.line_total), 2) AS revenue_amount,
    ROUND(AVG(oi.line_total), 2) AS avg_order_line_amount
FROM latest_quarter lq
JOIN household_store.sales_order so
    ON date_trunc('quarter', so.order_date) = lq.quarter_start
JOIN household_store.customer cu
    ON cu.customer_id = so.customer_id
JOIN household_store.order_item oi
    ON oi.order_id = so.order_id
JOIN household_store.product p
    ON p.product_id = oi.product_id
JOIN household_store.category c
    ON c.category_id = p.category_id
GROUP BY lq.quarter_start, c.category_name
ORDER BY revenue_amount DESC, c.category_name;

-- SECTION 7. READ-ONLY ROLE FOR MANAGER
DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_roles
        WHERE rolname = 'store_manager_readonly'
    ) THEN
        CREATE ROLE store_manager_readonly
            LOGIN
            PASSWORD 'manager'
            NOSUPERUSER
            NOCREATEDB
            NOCREATEROLE
            NOREPLICATION
            INHERIT;
    END IF;
END;
$$;

GRANT USAGE ON SCHEMA household_store TO store_manager_readonly;
GRANT SELECT ON ALL TABLES IN SCHEMA household_store TO store_manager_readonly;
ALTER DEFAULT PRIVILEGES IN SCHEMA household_store
GRANT SELECT ON TABLES TO store_manager_readonly;