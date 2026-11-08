-- Staging tablice za očišćene Olist podatke
--
-- Izvor:
-- CSV datoteke nastale u 02_ciscenje_podataka.ipynb
--
-- Staging sloj predstavlja očišćenu relacijsku reprezentaciju
-- izvornog Olist skupa podataka i služi kao izvor za ETL
-- postupak kojim se puni dimenzijski model u shemi dw.
--
-- U staging sloju zadržani su izvorni poslovni ključevi
-- te su definirani primarni i strani ključevi tamo gdje
-- struktura podataka to omogućava.


-- 1. CUSTOMERS
-- olist_customers_dataset_clean.csv

CREATE TABLE staging.customers (
    customer_id                         TEXT NOT NULL,
    customer_unique_id                  TEXT NOT NULL,
    customer_zip_code_prefix            INTEGER NOT NULL,
    customer_city                       TEXT NOT NULL,
    customer_state                      TEXT NOT NULL,
    customer_city_std                   TEXT NOT NULL,
    customer_state_std                  TEXT NOT NULL,
    customer_city_clean                 TEXT NOT NULL,
    customer_state_clean                TEXT NOT NULL,
    customer_city_corrected             BOOLEAN NOT NULL,
    customer_state_corrected            BOOLEAN NOT NULL,
    customer_correction_method          TEXT NOT NULL,
    customer_city_compact               TEXT NOT NULL,
    udaljenost_od_sao_paulo             INTEGER NOT NULL,
    referentna_drzava                   TEXT,
    customer_geolocation_matched        BOOLEAN NOT NULL,

    CONSTRAINT pk_customers
        PRIMARY KEY (customer_id)
);


-- 2. GEOLOCATION
-- olist_geolocation_dataset_clean.csv
--
-- Geolocation tablica nema prirodni jedinstveni ključ:
-- jedan ZIP code prefix može imati više geolokacijskih zapisa.
-- Tablica se koristi kao pomoćni izvor za geolokacijsko
-- usklađivanje i provjeru lokacija.

CREATE TABLE staging.geolocation (
    geolocation_zip_code_prefix       INTEGER NOT NULL,
    geolocation_lat                   DOUBLE PRECISION NOT NULL,
    geolocation_lng                   DOUBLE PRECISION NOT NULL,
    geolocation_city                  TEXT NOT NULL,
    geolocation_state                 TEXT NOT NULL,
    geolocation_city_std              TEXT NOT NULL,
    geolocation_state_std             TEXT NOT NULL,
    geolocation_city_clean            TEXT NOT NULL,
    geolocation_state_clean           TEXT NOT NULL,
    geolocation_city_corrected        BOOLEAN NOT NULL,
    geolocation_state_corrected       BOOLEAN NOT NULL,
    geolocation_correction_method     TEXT NOT NULL
);


-- 3. SELLERS
-- olist_sellers_dataset_clean.csv


CREATE TABLE staging.sellers (
    seller_id                         TEXT NOT NULL,
    seller_zip_code_prefix            INTEGER NOT NULL,
    seller_city                       TEXT NOT NULL,
    seller_state                      TEXT NOT NULL,
    seller_city_std                   TEXT NOT NULL,
    seller_state_std                  TEXT NOT NULL,
    seller_city_clean                 TEXT NOT NULL,
    seller_state_clean                TEXT NOT NULL,
    seller_city_corrected             BOOLEAN NOT NULL,
    seller_state_corrected            BOOLEAN NOT NULL,
    seller_correction_method          TEXT NOT NULL,
    referentna_drzava                 TEXT,
    seller_city_format_candidate      TEXT NOT NULL,
    seller_geolocation_matched        BOOLEAN NOT NULL,
    seller_city_invalid_format        BOOLEAN NOT NULL,

    CONSTRAINT pk_sellers
        PRIMARY KEY (seller_id)
);


-- 4. PRODUCTS
-- olist_products_dataset_clean.csv


CREATE TABLE staging.products (
    product_id                      TEXT NOT NULL,

    product_category_name           TEXT,

    product_name_lenght             DOUBLE PRECISION,
    product_description_lenght      DOUBLE PRECISION,
    product_photos_qty              DOUBLE PRECISION,

    product_weight_g                DOUBLE PRECISION,
    product_length_cm               DOUBLE PRECISION,
    product_height_cm               DOUBLE PRECISION,
    product_width_cm                DOUBLE PRECISION,

    product_category_name_clean     TEXT NOT NULL,
    missing_category                BOOLEAN NOT NULL,
    product_category_name_english   TEXT NOT NULL,

    missing_dimensions              BOOLEAN NOT NULL,
    product_weight_invalid          BOOLEAN NOT NULL,

    product_weight_g_clean          DOUBLE PRECISION,
    product_volume_cm3              DOUBLE PRECISION,

    CONSTRAINT pk_products
        PRIMARY KEY (product_id)
);


-- 5. ORDERS
-- olist_orders_dataset_clean.csv


CREATE TABLE staging.orders (
    order_id                         TEXT NOT NULL,
    customer_id                      TEXT NOT NULL,
    order_status                     TEXT NOT NULL,

    order_purchase_timestamp         TIMESTAMP NOT NULL,
    order_approved_at                TIMESTAMP,
    order_delivered_carrier_date     TIMESTAMP,
    order_delivered_customer_date    TIMESTAMP,
    order_estimated_delivery_date    TIMESTAMP NOT NULL,

    approval_before_purchase         BOOLEAN NOT NULL,
    carrier_before_approval          BOOLEAN NOT NULL,
    customer_before_carrier          BOOLEAN NOT NULL,
    delivery_before_purchase         BOOLEAN NOT NULL,
    has_timeline_anomaly             BOOLEAN NOT NULL,
    customer_reference_valid         BOOLEAN NOT NULL,

    approval_time_hours              DOUBLE PRECISION,
    carrier_wait_days                DOUBLE PRECISION,
    shipping_time_days               DOUBLE PRECISION,
    delivery_time_days               DOUBLE PRECISION,
    delivery_delay_days              DOUBLE PRECISION,

    delivery_status                  TEXT,
    delivered_within_deadline        BOOLEAN,

    CONSTRAINT pk_orders
        PRIMARY KEY (order_id),

    CONSTRAINT fk_orders_customer
        FOREIGN KEY (customer_id)
        REFERENCES staging.customers(customer_id)
);


-- 6. ORDER ITEMS
-- olist_order_items_dataset_clean.csv


CREATE TABLE staging.order_items (
    order_id                     TEXT NOT NULL,
    order_item_id                INTEGER NOT NULL,
    product_id                   TEXT NOT NULL,
    seller_id                    TEXT NOT NULL,

    shipping_limit_date          TIMESTAMP NOT NULL,

    price                        NUMERIC(12,2) NOT NULL,
    freight_value                NUMERIC(12,2) NOT NULL,

    order_reference_valid        BOOLEAN NOT NULL,
    product_reference_valid      BOOLEAN NOT NULL,
    seller_reference_valid       BOOLEAN NOT NULL,

    price_invalid                BOOLEAN NOT NULL,
    freight_invalid              BOOLEAN NOT NULL,
    free_freight                 BOOLEAN NOT NULL,

    item_total_value             NUMERIC(12,2) NOT NULL,
    freight_percentage           DOUBLE PRECISION NOT NULL,

    price_outlier                BOOLEAN NOT NULL,
    freight_outlier              BOOLEAN NOT NULL,
    freight_greater_than_price   BOOLEAN NOT NULL,

    CONSTRAINT pk_order_items
        PRIMARY KEY (order_id, order_item_id),

    CONSTRAINT fk_order_items_order
        FOREIGN KEY (order_id)
        REFERENCES staging.orders(order_id),

    CONSTRAINT fk_order_items_product
        FOREIGN KEY (product_id)
        REFERENCES staging.products(product_id),

    CONSTRAINT fk_order_items_seller
        FOREIGN KEY (seller_id)
        REFERENCES staging.sellers(seller_id)
);


-- 7. PAYMENTS
-- olist_order_payments_dataset_clean.csv


CREATE TABLE staging.payments (
    order_id                    TEXT NOT NULL,
    payment_sequential          INTEGER NOT NULL,
    payment_type                TEXT NOT NULL,
    payment_installments        INTEGER NOT NULL,
    payment_value               NUMERIC(12,2) NOT NULL,

    payment_sequence_anomaly    BOOLEAN NOT NULL,
    installments_nonpositive    BOOLEAN NOT NULL,
    payment_value_zero          BOOLEAN NOT NULL,
    payment_value_negative      BOOLEAN NOT NULL,
    order_reference_valid       BOOLEAN NOT NULL,
    payment_value_outlier       BOOLEAN NOT NULL,
    payment_amount_mismatch     BOOLEAN NOT NULL,

    CONSTRAINT pk_payments
        PRIMARY KEY (order_id, payment_sequential),

    CONSTRAINT fk_payments_order
        FOREIGN KEY (order_id)
        REFERENCES staging.orders(order_id)
);



-- 8. REVIEWS
-- olist_order_reviews_dataset_clean.csv
--
-- U clean skupu zadržan je posljednji dostupni review
-- za svaku narudžbu.
--
-- Nakon čišćenja postoji najviše jedan zapis
-- po order_id, order_id je ključ staging tablice.


CREATE TABLE staging.reviews (
    review_id                        TEXT NOT NULL,
    order_id                         TEXT NOT NULL,
    review_score                     INTEGER NOT NULL,

    review_comment_title             TEXT,
    review_comment_message           TEXT,

    review_creation_date             TIMESTAMP NOT NULL,
    review_answer_timestamp          TIMESTAMP NOT NULL,

    review_score_invalid             BOOLEAN NOT NULL,
    order_reference_valid            BOOLEAN NOT NULL,
    has_review_title                 BOOLEAN NOT NULL,
    has_review_message               BOOLEAN NOT NULL,

    review_records_count             INTEGER NOT NULL,
    multiple_reviews_for_order       BOOLEAN NOT NULL,

    review_response_time_hours       DOUBLE PRECISION NOT NULL,
    review_response_before_creation  BOOLEAN NOT NULL,

    first_review_answer_timestamp    TIMESTAMP,
    first_review_response_time_hours DOUBLE PRECISION,

    CONSTRAINT pk_reviews
        PRIMARY KEY (order_id),

    CONSTRAINT fk_reviews_order
        FOREIGN KEY (order_id)
        REFERENCES staging.orders(order_id)
);


-- 9. CATEGORY TRANSLATION
-- product_category_name_translation_clean.csv
--
-- product_category_name predstavlja izvorni poslovni ključ.

CREATE TABLE staging.category_translation (
    product_category_name          TEXT NOT NULL,
    product_category_name_english  TEXT NOT NULL,

    CONSTRAINT pk_category_translation
        PRIMARY KEY (product_category_name)
);