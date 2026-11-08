-- Punjenje dimenzijskih tablica Olist skladišta podataka
--
-- Izvor: staging shema
-- Odredište: dw shema
--
-- Redoslijed:
--   1. dim_date
--   2. dim_time
--   3. dim_customer
--   4. dim_seller
--   5. dim_product
--   6. dim_category
--   7. dim_order_status
--   8. dim_payment_type


-- 1. DIM_DATE
--
-- Raspon datuma određuje se automatski iz svih vremenskih
-- atributa koji će se koristiti u fact tablicama.
--
-- date_key:
--   0        = Unknown
--   YYYYMMDD = stvarni datum


-- 1.1 Unknown datum

INSERT INTO dw.dim_date (
    date_key,
    full_date,
    day_of_month,
    day_of_week_iso,
    day_name,
    day_of_year,
    week_of_year,
    iso_week_year,
    week_start_date,
    week_end_date,
    month_number,
    month_name,
    month_start_date,
    month_end_date,
    quarter_number,
    year_number,
    is_weekend,
    season,
    is_unknown
)
VALUES (
    0,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    FALSE,
    NULL,
    TRUE
);


-- 1.2 Generiranje kalendara
--
-- Uzimaju se svi datumi potrebni za buduće fact tablice.
--
-- Kalendarski raspon započinje prvim danom mjeseca
-- najranijeg datuma iz izvornih podataka.
--
-- Time se osigurava postojanje month_date_key za
-- mjesečne agregacije u fact_category_month_statistics.
--
-- Uključeni izvori:
--   orders:
--     purchase
--     approval
--     carrier
--     customer delivery
--     estimated delivery
--
--   order_items:
--     shipping limit
--
--   reviews:
--     creation
--     answer

WITH all_dates AS (

    SELECT order_purchase_timestamp::DATE AS datum
    FROM staging.orders

    UNION ALL

    SELECT order_approved_at::DATE
    FROM staging.orders
    WHERE order_approved_at IS NOT NULL

    UNION ALL

    SELECT order_delivered_carrier_date::DATE
    FROM staging.orders
    WHERE order_delivered_carrier_date IS NOT NULL

    UNION ALL

    SELECT order_delivered_customer_date::DATE
    FROM staging.orders
    WHERE order_delivered_customer_date IS NOT NULL

    UNION ALL

    SELECT order_estimated_delivery_date::DATE
    FROM staging.orders

    UNION ALL

    SELECT shipping_limit_date::DATE
    FROM staging.order_items

    UNION ALL

    SELECT review_creation_date::DATE
    FROM staging.reviews

    UNION ALL

    SELECT review_answer_timestamp::DATE
    FROM staging.reviews
),

date_bounds AS (
    SELECT
        DATE_TRUNC('month', MIN(datum))::DATE AS min_date,
        MAX(datum) AS max_date
    FROM all_dates
),

calendar AS (
    SELECT
        generate_series(
            min_date::TIMESTAMP,
            max_date::TIMESTAMP,
            INTERVAL '1 day'
        )::DATE AS full_date
    FROM date_bounds
)

INSERT INTO dw.dim_date (
    date_key,
    full_date,
    day_of_month,
    day_of_week_iso,
    day_name,
    day_of_year,
    week_of_year,
    iso_week_year,
    week_start_date,
    week_end_date,
    month_number,
    month_name,
    month_start_date,
    month_end_date,
    quarter_number,
    year_number,
    is_weekend,
    season,
    is_unknown
)
SELECT
    TO_CHAR(full_date, 'YYYYMMDD')::INTEGER,

    full_date,

    EXTRACT(DAY FROM full_date)::SMALLINT,

    EXTRACT(ISODOW FROM full_date)::SMALLINT,

    CASE EXTRACT(ISODOW FROM full_date)::INTEGER
        WHEN 1 THEN 'Monday'
        WHEN 2 THEN 'Tuesday'
        WHEN 3 THEN 'Wednesday'
        WHEN 4 THEN 'Thursday'
        WHEN 5 THEN 'Friday'
        WHEN 6 THEN 'Saturday'
        WHEN 7 THEN 'Sunday'
    END,

    EXTRACT(DOY FROM full_date)::SMALLINT,

    EXTRACT(WEEK FROM full_date)::SMALLINT,

    EXTRACT(ISOYEAR FROM full_date)::INTEGER,

    DATE_TRUNC('week', full_date)::DATE,

    (
        DATE_TRUNC('week', full_date)
        + INTERVAL '6 days'
    )::DATE,

    EXTRACT(MONTH FROM full_date)::SMALLINT,

    CASE EXTRACT(MONTH FROM full_date)::INTEGER
        WHEN 1 THEN 'January'
        WHEN 2 THEN 'February'
        WHEN 3 THEN 'March'
        WHEN 4 THEN 'April'
        WHEN 5 THEN 'May'
        WHEN 6 THEN 'June'
        WHEN 7 THEN 'July'
        WHEN 8 THEN 'August'
        WHEN 9 THEN 'September'
        WHEN 10 THEN 'October'
        WHEN 11 THEN 'November'
        WHEN 12 THEN 'December'
    END,

    DATE_TRUNC('month', full_date)::DATE,

    (
        DATE_TRUNC('month', full_date)
        + INTERVAL '1 month'
        - INTERVAL '1 day'
    )::DATE,

    EXTRACT(QUARTER FROM full_date)::SMALLINT,

    EXTRACT(YEAR FROM full_date)::INTEGER,

    EXTRACT(ISODOW FROM full_date) IN (6, 7),

    CASE
        WHEN (EXTRACT(MONTH FROM full_date) = 12
            AND EXTRACT(DAY FROM full_date) >= 21)
            OR EXTRACT(MONTH FROM full_date) IN (1, 2)
            OR (EXTRACT(MONTH FROM full_date) = 3
                AND EXTRACT(DAY FROM full_date) < 20)
            THEN 'summer'

        WHEN (EXTRACT(MONTH FROM full_date) = 3
            AND EXTRACT(DAY FROM full_date) >= 20)
            OR EXTRACT(MONTH FROM full_date) IN (4, 5)
            OR (EXTRACT(MONTH FROM full_date) = 6
                AND EXTRACT(DAY FROM full_date) < 21)
            THEN 'autumn'

        WHEN (EXTRACT(MONTH FROM full_date) = 6
            AND EXTRACT(DAY FROM full_date) >= 21)
            OR EXTRACT(MONTH FROM full_date) IN (7, 8)
            OR (EXTRACT(MONTH FROM full_date) = 9
                AND EXTRACT(DAY FROM full_date) < 22)
            THEN 'winter'

        ELSE 'spring'
    END,

    FALSE

FROM calendar
ORDER BY full_date;


-- 2. DIM_TIME
--
-- jedan redak = jedna minuta dana
--
-- 1 440 minuta + Unknown datum.
--
-- time_key:
--   0        = Unknown
--   1 - 1440 = stvarne minute dana
--
-- time_key = minute_of_day + 1
--
-- Primjeri:
--   00:00 -> 1
--   08:00 -> 481
--   12:30 -> 751
--   23:59 -> 1440


-- 2.1 Unknown datum

INSERT INTO dw.dim_time (
    time_key,
    full_time,
    hour_number,
    minute_number,
    minute_of_day,
    part_of_day,
    is_business_hours,
    is_unknown
)
VALUES (
    0,
    NULL,
    NULL,
    NULL,
    NULL,
    NULL,
    FALSE,
    TRUE
);


-- 2.2 Generiranje 1 440 minuta

WITH minutes AS (
    SELECT
        generate_series(0, 1439) AS minute_of_day
)

INSERT INTO dw.dim_time (
    time_key,
    full_time,
    hour_number,
    minute_number,
    minute_of_day,
    part_of_day,
    is_business_hours,
    is_unknown
)
SELECT
    minute_of_day + 1 AS time_key,

    MAKE_TIME(
        (minute_of_day / 60)::INTEGER,
        (minute_of_day % 60)::INTEGER,
        0
    ) AS full_time,

    (minute_of_day / 60)::SMALLINT AS hour_number,

    (minute_of_day % 60)::SMALLINT AS minute_number,

    minute_of_day::SMALLINT,

    CASE
        WHEN minute_of_day / 60 BETWEEN 0 AND 5
            THEN 'night'
        WHEN minute_of_day / 60 BETWEEN 6 AND 11
            THEN 'morning'
        WHEN minute_of_day / 60 BETWEEN 12 AND 17
            THEN 'afternoon'
        ELSE 'evening'
    END AS part_of_day,

    (minute_of_day / 60 BETWEEN 8 AND 16)
        AS is_business_hours,

    FALSE AS is_unknown

FROM minutes
ORDER BY minute_of_day;

-- 3. DIM_CUSTOMER
--
-- Jedan redak = jedan customer_id.
-- Koristimo očišćene vrijednosti grada i države
-- te zastavice koje označavaju provedene korekcije
-- i uspješnost geografskog povezivanja.

INSERT INTO dw.dim_customer (
    customer_id,
    customer_unique_id,
    customer_zip_code_prefix,
    customer_city,
    customer_state,
    customer_city_corrected_flag,
    customer_state_corrected_flag,
    customer_geolocation_matched_flag
)
SELECT
    c.customer_id,
    c.customer_unique_id,
    c.customer_zip_code_prefix,
    c.customer_city_clean,
    c.customer_state_clean,
    c.customer_city_corrected,
    c.customer_state_corrected,
    c.customer_geolocation_matched
FROM staging.customers AS c
ORDER BY c.customer_id;

-- 4. DIM_SELLER
--
-- jedan redak = jedan seller_id

INSERT INTO dw.dim_seller (
    seller_id,
    seller_zip_code_prefix,
    seller_city,
    seller_state,
    seller_city_corrected_flag,
    seller_state_corrected_flag,
    seller_geolocation_matched_flag,
    seller_city_invalid_format_flag
)
SELECT
    seller_id,
    seller_zip_code_prefix,

    seller_city_clean,
    seller_state_clean,

    seller_city_corrected,
    seller_state_corrected,
    seller_geolocation_matched,
    seller_city_invalid_format

FROM staging.sellers
ORDER BY seller_id;


-- 5. DIM_PRODUCT
--
-- jedan redak = jedan product_id
--
-- Koriste se očišćena kategorija i očišćena težina.

INSERT INTO dw.dim_product (
    product_id,
    category_name_portuguese,
    category_name_english,
    is_unknown_category,
    product_weight_g,
    product_length_cm,
    product_height_cm,
    product_width_cm,
    product_volume_cm3,
    missing_dimensions_flag,
    invalid_weight_flag
)
SELECT
    product_id,

    product_category_name_clean,
    product_category_name_english,
    missing_category,

    product_weight_g_clean,
    product_length_cm,
    product_height_cm,
    product_width_cm,
    product_volume_cm3,

    missing_dimensions,
    product_weight_invalid

FROM staging.products
ORDER BY product_id;


-- 6. DIM_CATEGORY
--
-- jedan redak = jedna standardizirana kategorija
--
-- Kategorije uzimamo iz konačnih očišćenih proizvoda jer time
-- dobivamo upravo skup kategorija koji se koristi u prodaji,
-- uključujući standardiziranu Unknown kategoriju.


INSERT INTO dw.dim_category (
    category_name_portuguese,
    category_name_english,
    is_unknown_category
)
SELECT DISTINCT
    product_category_name_clean,
    product_category_name_english,
    missing_category
FROM staging.products
ORDER BY product_category_name_clean;


-- 7. DIM_ORDER_STATUS
--
-- jedan redak = jedan status narudžbe
--
-- status_group:
--   open
--   completed
--   unsuccessful
--
-- status_phase_order predstavlja približan redoslijed
-- normalnog životnog ciklusa narudžbe.

INSERT INTO dw.dim_order_status (
    order_status,
    status_group,
    status_phase_order,
    is_final_status,
    is_successful_status
)
SELECT DISTINCT
    order_status,

    CASE
        WHEN order_status = 'delivered'
            THEN 'completed'

        WHEN order_status IN ('canceled', 'unavailable')
            THEN 'unsuccessful'

        ELSE 'open'
    END AS status_group,

    CASE order_status
        WHEN 'created'     THEN 1
        WHEN 'approved'    THEN 2
        WHEN 'invoiced'    THEN 3
        WHEN 'processing'  THEN 4
        WHEN 'shipped'     THEN 5
        WHEN 'delivered'   THEN 6
        WHEN 'canceled'    THEN 7
        WHEN 'unavailable' THEN 8
    END::SMALLINT AS status_phase_order,

    order_status IN (
        'delivered',
        'canceled',
        'unavailable'
    ) AS is_final_status,

    order_status = 'delivered'
        AS is_successful_status

FROM staging.orders
ORDER BY order_status;


-- 8. DIM_PAYMENT_TYPE
--
-- jedan redak = jedan tip plaćanja

INSERT INTO dw.dim_payment_type (
    payment_type,
    is_card_payment,
    supports_installments
)
SELECT DISTINCT
    payment_type,

    payment_type IN (
        'credit_card',
        'debit_card'
    ) AS is_card_payment,

    payment_type = 'credit_card'
        AS supports_installments

FROM staging.payments
ORDER BY payment_type;