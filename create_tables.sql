-- ==============================
-- TABLE: suppliers
-- ==============================
CREATE TABLE suppliers (
    supplier_id      NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    supplier_name    VARCHAR2(255) NOT NULL,
    contact_name     VARCHAR2(255),
    address          VARCHAR2(500),
    town             VARCHAR2(100),
    country          VARCHAR2(100),
    contact_number   VARCHAR2(50),
    email            VARCHAR2(255)
);

-- ==============================
-- TABLE: orders
-- ==============================
CREATE TABLE orders (
    order_id           NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    supplier_id        NUMBER NOT NULL,
    order_ref          VARCHAR2(50) NOT NULL,
    order_date         DATE NOT NULL,
    order_total_amount NUMBER,
    order_description  VARCHAR2(500),
    order_status       VARCHAR2(100),
    CONSTRAINT fk_orders_supplier FOREIGN KEY (supplier_id) REFERENCES suppliers(supplier_id)
);

-- ==============================
-- TABLE: order_items
-- ==============================
CREATE TABLE order_items (
    item_id          NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id        NUMBER NOT NULL,
    item_description VARCHAR2(500),
    item_amount      NUMBER,
    CONSTRAINT fk_order_items_order FOREIGN KEY (order_id) REFERENCES orders(order_id)
);

-- ==============================
-- TABLE: invoices
-- ==============================
CREATE TABLE invoices (
    invoice_id         NUMBER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    order_id           NUMBER NOT NULL,
    invoice_reference  VARCHAR2(100),
    invoice_date       DATE,
    invoice_status     VARCHAR2(100),
    invoice_hold_reason VARCHAR2(255),
    invoice_amount     NUMBER,
    invoice_description VARCHAR2(500),
    CONSTRAINT fk_invoices_order FOREIGN KEY (order_id) REFERENCES orders(order_id)
);