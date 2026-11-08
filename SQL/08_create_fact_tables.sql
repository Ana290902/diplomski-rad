-- Kreiranje činjeničnih tablica Olist skladišta podataka


-- 1. FACT_SALES
--
-- Poslovni proces: prodaja proizvoda
-- Grain: jedna stavka jedne narudžbe
--
-- Prirodna kontrola granulacije:
-- UNIQUE (order_id, order_item_id)
--
-- Referentna skupina za statistiku cijene:
-- kategorija proizvoda × kalendarski mjesec kupnje

CREATE TABLE dw.fact_sales (

    sales_key BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    -- Dimenzijski ključevi
    purchase_date_key INTEGER NOT NULL,
    purchase_time_key INTEGER NOT NULL,
    shipping_limit_date_key INTEGER NOT NULL,
    shipping_limit_time_key INTEGER NOT NULL,

    customer_key BIGINT NOT NULL,
    seller_key BIGINT NOT NULL,
    product_key BIGINT NOT NULL,
    order_status_key BIGINT NOT NULL,

    -- Degenerirane dimenzije / izvorna granulacija
    order_id TEXT NOT NULL,
    order_item_id INTEGER NOT NULL,

    -- Osnovne mjere
    item_count SMALLINT NOT NULL DEFAULT 1,
    product_value NUMERIC(12,2) NOT NULL,
    freight_value NUMERIC(12,2) NOT NULL,
    item_total_value NUMERIC(12,2) NOT NULL,
    freight_percentage NUMERIC(12,6),

    -- Poslovni indikatori
    free_freight_flag BOOLEAN NOT NULL,
    freight_greater_than_price_flag BOOLEAN NOT NULL,

    -- IQR outlier indikatori
    is_outlier_price BOOLEAN NOT NULL,
    is_outlier_freight BOOLEAN NOT NULL,

    -- Statističko obogaćivanje cijene
    category_month_price_mean NUMERIC(14,4),
    category_month_price_median NUMERIC(14,4),
    category_month_price_stddev NUMERIC(14,4),

    price_deviation_from_mean NUMERIC(14,4),

    price_quartile SMALLINT,
    price_percentile NUMERIC(8,6),

    price_reference_group_size INTEGER NOT NULL,
    price_statistics_valid BOOLEAN NOT NULL,

    -- Foreign keys

    CONSTRAINT fk_fact_sales_purchase_date
        FOREIGN KEY (purchase_date_key)
        REFERENCES dw.dim_date(date_key),

    CONSTRAINT fk_fact_sales_purchase_time
        FOREIGN KEY (purchase_time_key)
        REFERENCES dw.dim_time(time_key),

    CONSTRAINT fk_fact_sales_shipping_limit_date
        FOREIGN KEY (shipping_limit_date_key)
        REFERENCES dw.dim_date(date_key),

    CONSTRAINT fk_fact_sales_shipping_limit_time
        FOREIGN KEY (shipping_limit_time_key)
        REFERENCES dw.dim_time(time_key),

    CONSTRAINT fk_fact_sales_customer
        FOREIGN KEY (customer_key)
        REFERENCES dw.dim_customer(customer_key),

    CONSTRAINT fk_fact_sales_seller
        FOREIGN KEY (seller_key)
        REFERENCES dw.dim_seller(seller_key),

    CONSTRAINT fk_fact_sales_product
        FOREIGN KEY (product_key)
        REFERENCES dw.dim_product(product_key),

    CONSTRAINT fk_fact_sales_order_status
        FOREIGN KEY (order_status_key)
        REFERENCES dw.dim_order_status(order_status_key),

    -- Grain

    CONSTRAINT uq_fact_sales_grain
        UNIQUE (order_id, order_item_id),

    -- Checks

    CONSTRAINT chk_fact_sales_item_count
        CHECK (item_count = 1),

    CONSTRAINT chk_fact_sales_product_value
        CHECK (product_value > 0),

    CONSTRAINT chk_fact_sales_freight
        CHECK (freight_value >= 0),

    CONSTRAINT chk_fact_sales_total
        CHECK (item_total_value >= product_value),

    CONSTRAINT chk_fact_sales_freight_percentage
        CHECK (
            freight_percentage IS NULL
            OR freight_percentage BETWEEN 0 AND 1
        ),

    CONSTRAINT chk_fact_sales_price_quartile
        CHECK (
            price_quartile IS NULL
            OR price_quartile BETWEEN 1 AND 4
        ),

    CONSTRAINT chk_fact_sales_price_percentile
        CHECK (
            price_percentile IS NULL
            OR price_percentile BETWEEN 0 AND 1
        ),

    CONSTRAINT chk_fact_sales_group_size
        CHECK (price_reference_group_size > 0)
);



-- 2. FACT_ORDER_LIFECYCLE
--
-- Poslovni proces: obrada i dostava narudžbe
-- Grain: jedna narudžba
--
-- Prirodna kontrola granulacije:
-- UNIQUE (order_id)
--
-- Referentna skupina statistike vrijednosti narudžbe:
-- kalendarski mjesec kupnje

CREATE TABLE dw.fact_order_lifecycle (

    order_lifecycle_key BIGINT
        GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    -- Dimenzijski ključevi
    customer_key BIGINT NOT NULL,
    order_status_key BIGINT NOT NULL,

    purchase_date_key INTEGER NOT NULL,
    purchase_time_key INTEGER NOT NULL,

    approval_date_key INTEGER NOT NULL,
    approval_time_key INTEGER NOT NULL,

    carrier_date_key INTEGER NOT NULL,
    carrier_time_key INTEGER NOT NULL,

    delivery_date_key INTEGER NOT NULL,
    delivery_time_key INTEGER NOT NULL,

    estimated_delivery_date_key INTEGER NOT NULL,

    -- Degenerirana dimenzija
    order_id TEXT NOT NULL,

    -- Osnovne mjere
    order_count SMALLINT NOT NULL DEFAULT 1,

    item_count INTEGER NOT NULL,

    product_value NUMERIC(14,2) NOT NULL,
    freight_value NUMERIC(14,2) NOT NULL,
    order_total_value NUMERIC(14,2) NOT NULL,

    payment_total_value NUMERIC(14,2),

    payment_difference NUMERIC(14,2),
    payment_mismatch_flag BOOLEAN NOT NULL,

    -- Trajanja
    approval_time_hours NUMERIC(14,4),
    carrier_wait_days NUMERIC(14,4),
    shipping_time_days NUMERIC(14,4),
    delivery_time_days NUMERIC(14,4),
    delivery_delay_days NUMERIC(14,4),

    -- Status dostave
    delivered_within_deadline BOOLEAN,

    -- Indikatori kvalitete
    timeline_anomaly_flag BOOLEAN NOT NULL,

    -- IQR outlieri
    is_outlier_order_value BOOLEAN NOT NULL,
    is_outlier_delivery_time BOOLEAN,

    -- Statistika vrijednosti narudžbe
    month_order_value_mean NUMERIC(14,4),
    month_order_value_median NUMERIC(14,4),
    month_order_value_stddev NUMERIC(14,4),

    order_value_deviation_from_mean NUMERIC(14,4),

    order_value_quartile SMALLINT,
    order_value_percentile NUMERIC(8,6),

    order_value_reference_group_size INTEGER NOT NULL,
    order_value_statistics_valid BOOLEAN NOT NULL,

    -- Foreign keys

    CONSTRAINT fk_fact_lifecycle_customer
        FOREIGN KEY (customer_key)
        REFERENCES dw.dim_customer(customer_key),

    CONSTRAINT fk_fact_lifecycle_status
        FOREIGN KEY (order_status_key)
        REFERENCES dw.dim_order_status(order_status_key),

    CONSTRAINT fk_fact_lifecycle_purchase_date
        FOREIGN KEY (purchase_date_key)
        REFERENCES dw.dim_date(date_key),

    CONSTRAINT fk_fact_lifecycle_purchase_time
        FOREIGN KEY (purchase_time_key)
        REFERENCES dw.dim_time(time_key),

    CONSTRAINT fk_fact_lifecycle_approval_date
        FOREIGN KEY (approval_date_key)
        REFERENCES dw.dim_date(date_key),

    CONSTRAINT fk_fact_lifecycle_approval_time
        FOREIGN KEY (approval_time_key)
        REFERENCES dw.dim_time(time_key),

    CONSTRAINT fk_fact_lifecycle_carrier_date
        FOREIGN KEY (carrier_date_key)
        REFERENCES dw.dim_date(date_key),

    CONSTRAINT fk_fact_lifecycle_carrier_time
        FOREIGN KEY (carrier_time_key)
        REFERENCES dw.dim_time(time_key),

    CONSTRAINT fk_fact_lifecycle_delivery_date
        FOREIGN KEY (delivery_date_key)
        REFERENCES dw.dim_date(date_key),

    CONSTRAINT fk_fact_lifecycle_delivery_time
        FOREIGN KEY (delivery_time_key)
        REFERENCES dw.dim_time(time_key),

    CONSTRAINT fk_fact_lifecycle_estimated_date
        FOREIGN KEY (estimated_delivery_date_key)
        REFERENCES dw.dim_date(date_key),

    -- Grain
    CONSTRAINT uq_fact_order_lifecycle_grain
        UNIQUE (order_id),

    -- Checks
    CONSTRAINT chk_fact_lifecycle_order_count
        CHECK (order_count = 1),

    CONSTRAINT chk_fact_lifecycle_item_count
        CHECK (item_count >= 0),

    CONSTRAINT chk_fact_lifecycle_product_value
        CHECK (product_value >= 0),

    CONSTRAINT chk_fact_lifecycle_freight
        CHECK (freight_value >= 0),

    CONSTRAINT chk_fact_lifecycle_total
        CHECK (order_total_value >= 0),

    CONSTRAINT chk_fact_lifecycle_payment
        CHECK (
            payment_total_value IS NULL
            OR payment_total_value >= 0
        ),

    CONSTRAINT chk_fact_lifecycle_quartile
        CHECK (
            order_value_quartile IS NULL
            OR order_value_quartile BETWEEN 1 AND 4
        ),

    CONSTRAINT chk_fact_lifecycle_percentile
        CHECK (
            order_value_percentile IS NULL
            OR order_value_percentile BETWEEN 0 AND 1
        ),

    CONSTRAINT chk_fact_lifecycle_group_size
        CHECK (order_value_reference_group_size > 0)
);



-- 3. FACT_PAYMENTS
--
-- Poslovni proces: plaćanje narudžbe
-- Grain: jedan izvorni zapis plaćanja
--
-- Prirodna kontrola granulacije:
-- UNIQUE (order_id, payment_sequential)

CREATE TABLE dw.fact_payments (

    payment_key BIGINT
        GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    -- Dimenzije
    purchase_date_key INTEGER NOT NULL,
    purchase_time_key INTEGER NOT NULL,
    customer_key BIGINT NOT NULL,
    payment_type_key BIGINT NOT NULL,

    -- Degenerirana dimenzija / izvorna granulacija
    order_id TEXT NOT NULL,
    payment_sequential INTEGER NOT NULL,

    -- Mjere
    payment_value NUMERIC(14,2) NOT NULL,
    payment_installments INTEGER NOT NULL,

    -- Indikatori
    zero_payment_flag BOOLEAN NOT NULL,
    nonpositive_installments_flag BOOLEAN NOT NULL,
    payment_sequence_anomaly_flag BOOLEAN NOT NULL,
    payment_outlier_flag BOOLEAN NOT NULL,

    -- Foreign keys
    CONSTRAINT fk_fact_payments_purchase_date
        FOREIGN KEY (purchase_date_key)
        REFERENCES dw.dim_date(date_key),

    CONSTRAINT fk_fact_payments_purchase_time
        FOREIGN KEY (purchase_time_key)
        REFERENCES dw.dim_time(time_key),

    CONSTRAINT fk_fact_payments_customer
        FOREIGN KEY (customer_key)
        REFERENCES dw.dim_customer(customer_key),

    CONSTRAINT fk_fact_payments_type
        FOREIGN KEY (payment_type_key)
        REFERENCES dw.dim_payment_type(payment_type_key),

    -- Grain
    CONSTRAINT uq_fact_payments_grain
        UNIQUE (order_id, payment_sequential),

    -- Checks
    CONSTRAINT chk_fact_payments_value
        CHECK (payment_value >= 0),

    CONSTRAINT chk_fact_payments_sequential
        CHECK (payment_sequential > 0)
);



-- 4. FACT_REVIEWS
--
-- Poslovni proces: završna povratna informacija kupca
-- Grain: posljednja dostupna recenzija jedne narudžbe
--
-- Prirodna kontrola granulacije:
-- UNIQUE (order_id)
--


CREATE TABLE dw.fact_reviews (

    review_key BIGINT
        GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    -- Dimenzije
    customer_key BIGINT NOT NULL,
    order_status_key BIGINT NOT NULL,

    purchase_date_key INTEGER NOT NULL,
    purchase_time_key INTEGER NOT NULL,

    review_creation_date_key INTEGER NOT NULL,
    review_creation_time_key INTEGER NOT NULL,

    review_answer_date_key INTEGER NOT NULL,
    review_answer_time_key INTEGER NOT NULL,

    -- Degenerirana dimenzija / izvorni atribut
    order_id TEXT NOT NULL,
    review_id TEXT NOT NULL,

    -- Mjere
    review_score SMALLINT NOT NULL,
    review_response_time_hours NUMERIC(14,4),

    -- Tekstualna obilježja
    has_review_title BOOLEAN NOT NULL,
    has_review_message BOOLEAN NOT NULL,

    -- Analitički indikatori
    low_score_flag BOOLEAN NOT NULL,
    multiple_reviews_source_flag BOOLEAN NOT NULL,

    -- Foreign keys
    CONSTRAINT fk_fact_reviews_customer
        FOREIGN KEY (customer_key)
        REFERENCES dw.dim_customer(customer_key),

    CONSTRAINT fk_fact_reviews_status
        FOREIGN KEY (order_status_key)
        REFERENCES dw.dim_order_status(order_status_key),

    CONSTRAINT fk_fact_reviews_purchase_date
        FOREIGN KEY (purchase_date_key)
        REFERENCES dw.dim_date(date_key),

    CONSTRAINT fk_fact_reviews_purchase_time
        FOREIGN KEY (purchase_time_key)
        REFERENCES dw.dim_time(time_key),

    CONSTRAINT fk_fact_reviews_creation_date
        FOREIGN KEY (review_creation_date_key)
        REFERENCES dw.dim_date(date_key),

    CONSTRAINT fk_fact_reviews_creation_time
        FOREIGN KEY (review_creation_time_key)
        REFERENCES dw.dim_time(time_key),

    CONSTRAINT fk_fact_reviews_answer_date
        FOREIGN KEY (review_answer_date_key)
        REFERENCES dw.dim_date(date_key),

    CONSTRAINT fk_fact_reviews_answer_time
        FOREIGN KEY (review_answer_time_key)
        REFERENCES dw.dim_time(time_key),

    -- Grain
    CONSTRAINT uq_fact_reviews_grain
        UNIQUE (order_id),

    -- Checks
    CONSTRAINT chk_fact_reviews_score
        CHECK (review_score BETWEEN 1 AND 5),

    CONSTRAINT chk_fact_reviews_response
        CHECK (
            review_response_time_hours IS NULL
            OR review_response_time_hours >= 0
        )
);



-- 5. FACT_CATEGORY_MONTH_STATISTICS
--
-- Poslovni proces:
-- mjesečni statistički sažetak prodaje po kategoriji
--
-- Grain:
-- jedna kategorija × jedan kalendarski mjesec
--
-- month_date_key pokazuje na prvi dan mjeseca u dim_date.
--
-- Korelacije se smatraju pouzdanima kada:
--   n >= 50
--   i obje varijable imaju nenultu varijancu.

CREATE TABLE dw.fact_category_month_statistics (

    category_month_statistics_key BIGINT
        GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    -- Dimenzije
    month_date_key INTEGER NOT NULL,
    category_key BIGINT NOT NULL,

    -- Aditivne osnovne mjere
    sales_item_count INTEGER NOT NULL,
    order_count INTEGER NOT NULL,

    product_value_sum NUMERIC(16,2) NOT NULL,
    freight_value_sum NUMERIC(16,2) NOT NULL,
    item_total_value_sum NUMERIC(16,2) NOT NULL,

    free_freight_item_count INTEGER NOT NULL,
    price_outlier_count INTEGER NOT NULL,
    freight_outlier_count INTEGER NOT NULL,

    -- Statistika cijene
    price_mean NUMERIC(14,4),
    price_median NUMERIC(14,4),
    price_stddev NUMERIC(14,4),

    price_min NUMERIC(14,2),
    price_max NUMERIC(14,2),

    price_q1 NUMERIC(14,4),
    price_q3 NUMERIC(14,4),
    price_iqr NUMERIC(14,4),

    -- Statistika dostave
    freight_mean NUMERIC(14,4),
    freight_median NUMERIC(14,4),
    freight_stddev NUMERIC(14,4),

    freight_min NUMERIC(14,2),
    freight_max NUMERIC(14,2),

    freight_q1 NUMERIC(14,4),
    freight_q3 NUMERIC(14,4),
    freight_iqr NUMERIC(14,4),

    -- Korelacije

    price_freight_correlation NUMERIC(12,8),
    price_freight_n INTEGER NOT NULL,
    price_freight_correlation_valid BOOLEAN NOT NULL,

    weight_freight_correlation NUMERIC(12,8),
    weight_freight_n INTEGER NOT NULL,
    weight_freight_correlation_valid BOOLEAN NOT NULL,

    volume_freight_correlation NUMERIC(12,8),
    volume_freight_n INTEGER NOT NULL,
    volume_freight_correlation_valid BOOLEAN NOT NULL,

    -- Foreign keys
    CONSTRAINT fk_fact_category_month_date
        FOREIGN KEY (month_date_key)
        REFERENCES dw.dim_date(date_key),

    CONSTRAINT fk_fact_category_month_category
        FOREIGN KEY (category_key)
        REFERENCES dw.dim_category(category_key),

    -- Grain
    CONSTRAINT uq_fact_category_month_grain
        UNIQUE (month_date_key, category_key),

    -- Checks
    CONSTRAINT chk_fact_category_month_sales_count
        CHECK (sales_item_count > 0),

    CONSTRAINT chk_fact_category_month_order_count
        CHECK (order_count > 0),

    CONSTRAINT chk_fact_category_month_orders_vs_items
        CHECK (order_count <= sales_item_count),

    CONSTRAINT chk_fact_category_month_product_sum
        CHECK (product_value_sum > 0),

    CONSTRAINT chk_fact_category_month_freight_sum
        CHECK (freight_value_sum >= 0),

    CONSTRAINT chk_fact_category_month_total_sum
        CHECK (item_total_value_sum > 0),

    CONSTRAINT chk_fact_category_month_free_freight_count
        CHECK (
            free_freight_item_count
            BETWEEN 0 AND sales_item_count
        ),

    CONSTRAINT chk_fact_category_month_price_outlier_count
        CHECK (
            price_outlier_count
            BETWEEN 0 AND sales_item_count
        ),

    CONSTRAINT chk_fact_category_month_freight_outlier_count
        CHECK (
            freight_outlier_count
            BETWEEN 0 AND sales_item_count
        ),

    CONSTRAINT chk_fact_category_month_price_corr
        CHECK (
            price_freight_correlation IS NULL
            OR price_freight_correlation BETWEEN -1 AND 1
        ),

    CONSTRAINT chk_fact_category_month_weight_corr
        CHECK (
            weight_freight_correlation IS NULL
            OR weight_freight_correlation BETWEEN -1 AND 1
        ),

    CONSTRAINT chk_fact_category_month_volume_corr
        CHECK (
            volume_freight_correlation IS NULL
            OR volume_freight_correlation BETWEEN -1 AND 1
        ),

    CONSTRAINT chk_fact_category_month_price_n
        CHECK (
            price_freight_n BETWEEN 0 AND sales_item_count
        ),

    CONSTRAINT chk_fact_category_month_weight_n
        CHECK (
            weight_freight_n BETWEEN 0 AND sales_item_count
        ),

    CONSTRAINT chk_fact_category_month_volume_n
        CHECK (
            volume_freight_n BETWEEN 0 AND sales_item_count
        )
);
