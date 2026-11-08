-- Kreiranje dimenzijskih tablica Olist skladišta podataka
--
-- Dimenzije:
--   1. dim_date
--   2. dim_time
--   3. dim_customer
--   4. dim_seller
--   5. dim_product
--   6. dim_category
--   7. dim_order_status
--   8. dim_payment_type
--
-- Dimenzije koriste surogatne primarne ključeve.
-- Izvorni poslovni ključevi zadržavaju se kao atributi
-- radi povezivanja sa staging slojem tijekom ETL-a.


-- 1. DIM_DATE
--
-- jedan redak = jedan kalendarski datum
--
-- Poseban Unknown zapis koristit će date_key = 0.

CREATE TABLE dw.dim_date (
    date_key            INTEGER NOT NULL,
    full_date           DATE,

    day_of_month        SMALLINT,
    day_of_week_iso     SMALLINT,
    day_name            TEXT,
    day_of_year         SMALLINT,

    week_of_year        SMALLINT,
    iso_week_year       INTEGER,
    -- prvi i posljednji datum ISO tjedna kojem full_date pripada
    week_start_date     DATE,
    week_end_date       DATE,

    month_number        SMALLINT,
    month_name          TEXT,
    -- prvi i posljednji datum mjeseca kojem full_date pripada
    month_start_date    DATE,
    month_end_date      DATE,

    quarter_number      SMALLINT,
    year_number         INTEGER,

    is_weekend          BOOLEAN NOT NULL,
    season              TEXT,
    is_unknown          BOOLEAN NOT NULL,

    CONSTRAINT pk_dim_date
        PRIMARY KEY (date_key),

    CONSTRAINT uq_dim_date_full_date
        UNIQUE (full_date),

    CONSTRAINT chk_dim_date_day
        CHECK (
            is_unknown = TRUE
            OR day_of_month BETWEEN 1 AND 31
        ),

    CONSTRAINT chk_dim_date_weekday
        CHECK (
            is_unknown = TRUE
            OR day_of_week_iso BETWEEN 1 AND 7
        ),

    CONSTRAINT chk_dim_date_month
        CHECK (
            is_unknown = TRUE
            OR month_number BETWEEN 1 AND 12
        ),

    CONSTRAINT chk_dim_date_quarter
        CHECK (
            is_unknown = TRUE
            OR quarter_number BETWEEN 1 AND 4
        )
);


-- 2. DIM_TIME
--
-- jedan redak = jedna minuta unutar dana
--
-- 1 440 minuta + Unknown zapis.
-- Poseban Unknown zapis koristit će time_key = 0.

CREATE TABLE dw.dim_time (
    time_key            INTEGER NOT NULL,
    full_time           TIME,

    hour_number         SMALLINT,
    minute_number       SMALLINT,
    minute_of_day       SMALLINT,

    part_of_day         TEXT,
    is_business_hours   BOOLEAN NOT NULL,
    is_unknown          BOOLEAN NOT NULL,

    CONSTRAINT pk_dim_time
        PRIMARY KEY (time_key),

    CONSTRAINT uq_dim_time_full_time
        UNIQUE (full_time),

    CONSTRAINT chk_dim_time_hour
        CHECK (
            is_unknown = TRUE
            OR hour_number BETWEEN 0 AND 23
        ),

    CONSTRAINT chk_dim_time_minute
        CHECK (
            is_unknown = TRUE
            OR minute_number BETWEEN 0 AND 59
        ),

    CONSTRAINT chk_dim_time_minute_of_day
        CHECK (
            is_unknown = TRUE
            OR minute_of_day BETWEEN 0 AND 1439
        ),

    CONSTRAINT chk_dim_time_part_of_day
        CHECK (
            is_unknown = TRUE
            OR (
                (hour_number BETWEEN 0 AND 5  AND part_of_day = 'night')
                OR
                (hour_number BETWEEN 6 AND 11 AND part_of_day = 'morning')
                OR
                (hour_number BETWEEN 12 AND 17 AND part_of_day = 'afternoon')
                OR
                (hour_number BETWEEN 18 AND 23 AND part_of_day = 'evening')
            )
        ),
    
    CONSTRAINT chk_dim_time_business_hours
        CHECK (
            is_unknown = TRUE
            OR is_business_hours = (hour_number BETWEEN 8 AND 16)
        )
);


-- 3. DIM_CUSTOMER
--
-- jedan redak = jedan izvorni customer_id


CREATE TABLE dw.dim_customer (
    customer_key                       BIGINT GENERATED ALWAYS AS IDENTITY,
    customer_id                        TEXT NOT NULL,
    customer_unique_id                 TEXT NOT NULL,

    customer_zip_code_prefix           INTEGER NOT NULL,
    customer_city                      TEXT NOT NULL,
    customer_state                     TEXT NOT NULL,

    customer_city_corrected_flag       BOOLEAN NOT NULL,
    customer_state_corrected_flag      BOOLEAN NOT NULL,
    customer_geolocation_matched_flag  BOOLEAN NOT NULL,

    CONSTRAINT pk_dim_customer
        PRIMARY KEY (customer_key),

    CONSTRAINT uq_dim_customer_id
        UNIQUE (customer_id)
);


-- 4. DIM_SELLER
--
-- jedan redak = jedan izvorni seller_id

CREATE TABLE dw.dim_seller (
    seller_key                       BIGINT GENERATED ALWAYS AS IDENTITY,
    seller_id                        TEXT NOT NULL,

    seller_zip_code_prefix           INTEGER NOT NULL,
    seller_city                      TEXT NOT NULL,
    seller_state                     TEXT NOT NULL,

    seller_city_corrected_flag       BOOLEAN NOT NULL,
    seller_state_corrected_flag      BOOLEAN NOT NULL,
    seller_geolocation_matched_flag  BOOLEAN NOT NULL,
    seller_city_invalid_format_flag  BOOLEAN NOT NULL,

    CONSTRAINT pk_dim_seller
        PRIMARY KEY (seller_key),

    CONSTRAINT uq_dim_seller_id
        UNIQUE (seller_id)
);


-- 5. DIM_PRODUCT
--
-- jedan redak = jedan izvorni product_id

CREATE TABLE dw.dim_product (
    product_key                  BIGINT GENERATED ALWAYS AS IDENTITY,
    product_id                   TEXT NOT NULL,

    category_name_portuguese     TEXT NOT NULL,
    category_name_english        TEXT NOT NULL,
    is_unknown_category          BOOLEAN NOT NULL,

    product_weight_g             DOUBLE PRECISION,
    product_length_cm            DOUBLE PRECISION,
    product_height_cm            DOUBLE PRECISION,
    product_width_cm             DOUBLE PRECISION,
    product_volume_cm3           DOUBLE PRECISION,

    missing_dimensions_flag      BOOLEAN NOT NULL,
    invalid_weight_flag          BOOLEAN NOT NULL,

    CONSTRAINT pk_dim_product
        PRIMARY KEY (product_key),

    CONSTRAINT uq_dim_product_id
        UNIQUE (product_id)
);


-- 6. DIM_CATEGORY
--
-- jedan redak = jedna standardizirana kategorija proizvoda
--
-- Ova dimenzija prvenstveno se koristi uz
-- fact_category_month_statistics.

CREATE TABLE dw.dim_category (
    category_key              BIGINT GENERATED ALWAYS AS IDENTITY,
    category_name_portuguese  TEXT NOT NULL,
    category_name_english     TEXT NOT NULL,
    is_unknown_category       BOOLEAN NOT NULL,

    CONSTRAINT pk_dim_category
        PRIMARY KEY (category_key),

    CONSTRAINT uq_dim_category_name
        UNIQUE (category_name_portuguese)
);


-- 7. DIM_ORDER_STATUS
--
-- jedan redak = jedan standardizirani status narudžbe

CREATE TABLE dw.dim_order_status (
    order_status_key       BIGINT GENERATED ALWAYS AS IDENTITY,
    order_status           TEXT NOT NULL,

    status_group           TEXT NOT NULL,
    status_phase_order     SMALLINT,

    is_final_status        BOOLEAN NOT NULL,
    is_successful_status   BOOLEAN NOT NULL,

    CONSTRAINT pk_dim_order_status
        PRIMARY KEY (order_status_key),

    CONSTRAINT uq_dim_order_status
        UNIQUE (order_status),

    CONSTRAINT chk_dim_order_status_value
        CHECK (
            order_status IN (
                'created',
                'approved',
                'invoiced',
                'processing',
                'shipped',
                'delivered',
                'canceled',
                'unavailable'
            )
        ),

    CONSTRAINT chk_dim_order_status_phase
        CHECK (
            status_phase_order IS NULL
            OR status_phase_order > 0
        )
);


-- 8. DIM_PAYMENT_TYPE
--
-- jedan redak = jedan standardizirani tip plaćanja

CREATE TABLE dw.dim_payment_type (
    payment_type_key       BIGINT GENERATED ALWAYS AS IDENTITY,
    payment_type           TEXT NOT NULL,

    is_card_payment        BOOLEAN NOT NULL,
    supports_installments  BOOLEAN NOT NULL,

    CONSTRAINT pk_dim_payment_type
        PRIMARY KEY (payment_type_key),

    CONSTRAINT uq_dim_payment_type
        UNIQUE (payment_type),

    CONSTRAINT chk_dim_payment_type_value
        CHECK (
            payment_type IN (
                'credit_card',
                'debit_card',
                'boleto',
                'voucher',
                'not_defined'
            )
        )
);