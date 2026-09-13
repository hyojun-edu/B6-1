-- Cafe Order DB schema (SQLite)
PRAGMA foreign_keys = ON;

DROP TABLE IF EXISTS order_items;
DROP TABLE IF EXISTS orders;
DROP TABLE IF EXISTS menu_items;
DROP TABLE IF EXISTS menu_categories;
DROP TABLE IF EXISTS customers;

CREATE TABLE customers (
    customer_id INTEGER PRIMARY KEY,
    name TEXT NOT NULL,
    email TEXT NOT NULL UNIQUE,
    joined_at DATE NOT NULL
);

CREATE TABLE menu_categories (
    category_id INTEGER PRIMARY KEY,
    category_name TEXT NOT NULL UNIQUE
);

CREATE TABLE menu_items (
    item_id INTEGER PRIMARY KEY,
    category_id INTEGER NOT NULL,
    item_name TEXT NOT NULL UNIQUE,
    price INTEGER NOT NULL CHECK (price > 0),
    is_available INTEGER NOT NULL DEFAULT 1 CHECK (is_available IN (0, 1)),
    FOREIGN KEY (category_id) REFERENCES menu_categories(category_id)
);

CREATE TABLE orders (
    order_id INTEGER PRIMARY KEY,
    customer_id INTEGER NOT NULL,
    ordered_at DATETIME NOT NULL,
    order_status TEXT NOT NULL CHECK (order_status IN ('PAID', 'READY', 'COMPLETED', 'CANCELLED')),
    FOREIGN KEY (customer_id) REFERENCES customers(customer_id)
);

CREATE TABLE order_items (
    order_item_id INTEGER PRIMARY KEY,
    order_id INTEGER NOT NULL,
    item_id INTEGER NOT NULL,
    quantity INTEGER NOT NULL CHECK (quantity > 0),
    unit_price INTEGER NOT NULL CHECK (unit_price > 0),
    FOREIGN KEY (order_id) REFERENCES orders(order_id) ON DELETE CASCADE,
    FOREIGN KEY (item_id) REFERENCES menu_items(item_id),
    UNIQUE (order_id, item_id)
);

-- 메뉴명 검색과 카테고리별 메뉴 조회를 빠르게 하기 위한 인덱스
CREATE INDEX idx_menu_items_category_id ON menu_items(category_id);
CREATE INDEX idx_orders_ordered_at ON orders(ordered_at);
