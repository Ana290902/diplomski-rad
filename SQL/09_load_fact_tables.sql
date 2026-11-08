
-- 1. PUNJENJE FACT_SALES
--
-- Grain: jedna stavka narudžbe
-- Statistička skupina: kategorija × mjesec kupnje

BEGIN;

WITH base_sales AS (
    SELECT
        oi.order_id,
        oi.order_item_id,

        o.order_purchase_timestamp AS purchase_ts,
        oi.shipping_limit_date AS shipping_limit_ts,

        dc.customer_key,
        ds.seller_key,
        dp.product_key,
        dos.order_status_key,

        dp.category_name_portuguese AS category_name,
        DATE_TRUNC(
            'month', o.order_purchase_timestamp
        )::DATE AS purchase_month,

        oi.price::NUMERIC AS product_value,
        oi.freight_value::NUMERIC AS freight_value

    FROM staging.order_items oi

    JOIN staging.orders o
        ON o.order_id = oi.order_id

    JOIN dw.dim_customer dc
        ON dc.customer_id = o.customer_id

    JOIN dw.dim_seller ds
        ON ds.seller_id = oi.seller_id

    JOIN dw.dim_product dp
        ON dp.product_id = oi.product_id

    JOIN dw.dim_order_status dos
        ON dos.order_status = o.order_status
),

group_statistics AS (
    SELECT
        category_name,
        purchase_month,

        COUNT(*)::INTEGER AS group_size,

        AVG(product_value) AS price_mean,
        STDDEV_SAMP(product_value) AS price_stddev,

        PERCENTILE_CONT(0.25)
            WITHIN GROUP (ORDER BY product_value)
            AS price_q1,

        PERCENTILE_CONT(0.50)
            WITHIN GROUP (ORDER BY product_value)
            AS price_median,

        PERCENTILE_CONT(0.75)
            WITHIN GROUP (ORDER BY product_value)
            AS price_q3,

        PERCENTILE_CONT(0.25)
            WITHIN GROUP (ORDER BY freight_value)
            AS freight_q1,

        PERCENTILE_CONT(0.75)
            WITHIN GROUP (ORDER BY freight_value)
            AS freight_q3

    FROM base_sales

    GROUP BY
        category_name,
        purchase_month
),

scored_sales AS (
    SELECT
        b.*,

        gs.group_size,
        gs.price_mean,
        gs.price_median,
        gs.price_stddev,

        gs.price_q1,
        gs.price_q3,
        gs.freight_q1,
        gs.freight_q3,

        NTILE(4) OVER (
            PARTITION BY b.category_name, b.purchase_month
            ORDER BY b.product_value, b.order_id, b.order_item_id
        ) AS price_quartile,

        PERCENT_RANK() OVER (
            PARTITION BY b.category_name, b.purchase_month
            ORDER BY b.product_value
        ) AS price_percentile

    FROM base_sales b

    JOIN group_statistics gs
        ON gs.category_name = b.category_name
       AND gs.purchase_month = b.purchase_month
)

INSERT INTO dw.fact_sales (
    purchase_date_key,
    purchase_time_key,
    shipping_limit_date_key,
    shipping_limit_time_key,

    customer_key,
    seller_key,
    product_key,
    order_status_key,

    order_id,
    order_item_id,

    item_count,
    product_value,
    freight_value,
    item_total_value,
    freight_percentage,

    free_freight_flag,
    freight_greater_than_price_flag,

    is_outlier_price,
    is_outlier_freight,

    category_month_price_mean,
    category_month_price_median,
    category_month_price_stddev,

    price_deviation_from_mean,
    price_quartile,
    price_percentile,

    price_reference_group_size,
    price_statistics_valid
)

SELECT
    -- Datumi i vremena
    COALESCE(
        TO_CHAR(s.purchase_ts, 'YYYYMMDD')::INTEGER, 0
    ),

    COALESCE(
        EXTRACT(HOUR FROM s.purchase_ts)::INTEGER * 60
        + EXTRACT(MINUTE FROM s.purchase_ts)::INTEGER + 1,
        0
    ),

    COALESCE(
        TO_CHAR(s.shipping_limit_ts, 'YYYYMMDD')::INTEGER, 0
    ),

    COALESCE(
        EXTRACT(HOUR FROM s.shipping_limit_ts)::INTEGER * 60
        + EXTRACT(MINUTE FROM s.shipping_limit_ts)::INTEGER + 1,
        0
    ),

    -- Dimenzijski ključevi
    s.customer_key,
    s.seller_key,
    s.product_key,
    s.order_status_key,

    -- Izvorna granulacija
    s.order_id,
    s.order_item_id,

    -- Osnovne mjere
    1,
    s.product_value,
    s.freight_value,
    s.product_value + s.freight_value,

    ROUND(
        s.freight_value
        / NULLIF(s.product_value + s.freight_value, 0),
        6
    ),

    -- Poslovni indikatori
    (s.freight_value = 0),
    (s.freight_value > s.product_value),

    -- IQR indikatori unutar kategorije i mjeseca
    (
        s.product_value <
            s.price_q1 - 1.5 * (s.price_q3 - s.price_q1)
        OR
        s.product_value >
            s.price_q3 + 1.5 * (s.price_q3 - s.price_q1)
    ),

    (
        s.freight_value <
            s.freight_q1 - 1.5 * (s.freight_q3 - s.freight_q1)
        OR
        s.freight_value >
            s.freight_q3 + 1.5 * (s.freight_q3 - s.freight_q1)
    ),

    -- Statistike cijene
    ROUND(s.price_mean, 4),
    ROUND(s.price_median::NUMERIC, 4),
    ROUND(s.price_stddev, 4),

    ROUND(s.product_value - s.price_mean, 4),

    s.price_quartile,
    ROUND(s.price_percentile::NUMERIC, 6),

    s.group_size,

    (
        s.group_size >= 2
        AND COALESCE(s.price_stddev > 0, FALSE)
    )

FROM scored_sales s;

COMMIT;

-- 2. PUNJENJE FACT_ORDER_LIFECYCLE
--
-- Grain: jedna narudžba
-- Statistička skupina: mjesec kupnje

BEGIN;

WITH order_items_agg AS (
    SELECT
        order_id,
        COUNT(*)::INTEGER AS item_count,
        SUM(price)::NUMERIC AS product_value,
        SUM(freight_value)::NUMERIC AS freight_value

    FROM staging.order_items
    GROUP BY order_id
),

payments_agg AS (
    SELECT
        order_id,
        SUM(payment_value)::NUMERIC AS payment_total_value

    FROM staging.payments
    GROUP BY order_id
),

base_orders AS (
    SELECT
        o.order_id,

        dc.customer_key,
        dos.order_status_key,

        o.order_purchase_timestamp AS purchase_ts,
        o.order_approved_at AS approval_ts,
        o.order_delivered_carrier_date AS carrier_ts,
        o.order_delivered_customer_date AS delivery_ts,
        o.order_estimated_delivery_date AS estimated_delivery_ts,

        DATE_TRUNC(
            'month', o.order_purchase_timestamp
        )::DATE AS purchase_month,

        COALESCE(oi.item_count, 0) AS item_count,
        COALESCE(oi.product_value, 0)::NUMERIC AS product_value,
        COALESCE(oi.freight_value, 0)::NUMERIC AS freight_value,

        (
            COALESCE(oi.product_value, 0)
            + COALESCE(oi.freight_value, 0)
        )::NUMERIC AS order_total_value,

        pa.payment_total_value,

        o.approval_time_hours,
        o.carrier_wait_days,
        o.shipping_time_days,
        o.delivery_time_days,
        o.delivery_delay_days,
        o.delivered_within_deadline,
        o.has_timeline_anomaly AS timeline_anomaly_flag

    FROM staging.orders o

    JOIN dw.dim_customer dc
        ON dc.customer_id = o.customer_id

    JOIN dw.dim_order_status dos
        ON dos.order_status = o.order_status

    LEFT JOIN order_items_agg oi
        ON oi.order_id = o.order_id

    LEFT JOIN payments_agg pa
        ON pa.order_id = o.order_id
),

monthly_statistics AS (
    SELECT
        purchase_month,

        COUNT(*)::INTEGER AS group_size,

        AVG(order_total_value) AS order_value_mean,

        STDDEV_SAMP(order_total_value)
            AS order_value_stddev,

        PERCENTILE_CONT(0.25)
            WITHIN GROUP (ORDER BY order_total_value)
            AS order_value_q1,

        PERCENTILE_CONT(0.50)
            WITHIN GROUP (ORDER BY order_total_value)
            AS order_value_median,

        PERCENTILE_CONT(0.75)
            WITHIN GROUP (ORDER BY order_total_value)
            AS order_value_q3

    FROM base_orders
    GROUP BY purchase_month
),

delivery_statistics AS (
    SELECT
        purchase_month,

        PERCENTILE_CONT(0.25)
            WITHIN GROUP (ORDER BY delivery_time_days)
            AS delivery_q1,

        PERCENTILE_CONT(0.75)
            WITHIN GROUP (ORDER BY delivery_time_days)
            AS delivery_q3

    FROM base_orders

    WHERE delivery_time_days IS NOT NULL
      AND delivery_time_days >= 0

    GROUP BY purchase_month
),

scored_orders AS (
    SELECT
        b.*,

        ms.group_size,
        ms.order_value_mean,
        ms.order_value_median,
        ms.order_value_stddev,
        ms.order_value_q1,
        ms.order_value_q3,

        ds.delivery_q1,
        ds.delivery_q3,

        NTILE(4) OVER (
            PARTITION BY b.purchase_month
            ORDER BY b.order_total_value, b.order_id
        ) AS order_value_quartile,

        PERCENT_RANK() OVER (
            PARTITION BY b.purchase_month
            ORDER BY b.order_total_value
        ) AS order_value_percentile

    FROM base_orders b

    JOIN monthly_statistics ms
        ON ms.purchase_month = b.purchase_month

    LEFT JOIN delivery_statistics ds
        ON ds.purchase_month = b.purchase_month
)

INSERT INTO dw.fact_order_lifecycle (
    customer_key,
    order_status_key,

    purchase_date_key,
    purchase_time_key,
    approval_date_key,
    approval_time_key,
    carrier_date_key,
    carrier_time_key,
    delivery_date_key,
    delivery_time_key,
    estimated_delivery_date_key,

    order_id,
    order_count,
    item_count,

    product_value,
    freight_value,
    order_total_value,
    payment_total_value,
    payment_difference,
    payment_mismatch_flag,

    approval_time_hours,
    carrier_wait_days,
    shipping_time_days,
    delivery_time_days,
    delivery_delay_days,
    delivered_within_deadline,
    timeline_anomaly_flag,

    is_outlier_order_value,
    is_outlier_delivery_time,

    month_order_value_mean,
    month_order_value_median,
    month_order_value_stddev,
    order_value_deviation_from_mean,
    order_value_quartile,
    order_value_percentile,
    order_value_reference_group_size,
    order_value_statistics_valid
)

SELECT
    s.customer_key,
    s.order_status_key,

    -- Datum i vrijeme kupnje
    COALESCE(
        TO_CHAR(s.purchase_ts, 'YYYYMMDD')::INTEGER, 0
    ),

    COALESCE(
        EXTRACT(HOUR FROM s.purchase_ts)::INTEGER * 60
        + EXTRACT(MINUTE FROM s.purchase_ts)::INTEGER + 1,
        0
    ),

    -- Datum i vrijeme odobravanja
    COALESCE(
        TO_CHAR(s.approval_ts, 'YYYYMMDD')::INTEGER, 0
    ),

    COALESCE(
        EXTRACT(HOUR FROM s.approval_ts)::INTEGER * 60
        + EXTRACT(MINUTE FROM s.approval_ts)::INTEGER + 1,
        0
    ),

    -- Datum i vrijeme predaje dostavljaču
    COALESCE(
        TO_CHAR(s.carrier_ts, 'YYYYMMDD')::INTEGER, 0
    ),

    COALESCE(
        EXTRACT(HOUR FROM s.carrier_ts)::INTEGER * 60
        + EXTRACT(MINUTE FROM s.carrier_ts)::INTEGER + 1,
        0
    ),

    -- Datum i vrijeme isporuke kupcu
    COALESCE(
        TO_CHAR(s.delivery_ts, 'YYYYMMDD')::INTEGER, 0
    ),

    COALESCE(
        EXTRACT(HOUR FROM s.delivery_ts)::INTEGER * 60
        + EXTRACT(MINUTE FROM s.delivery_ts)::INTEGER + 1,
        0
    ),

    -- Procijenjeni datum isporuke
    COALESCE(
        TO_CHAR(s.estimated_delivery_ts, 'YYYYMMDD')::INTEGER, 0
    ),

    -- Identifikator i broj narudžbi
    s.order_id,
    1,
    s.item_count,

    -- Financijske mjere
    s.product_value,
    s.freight_value,
    s.order_total_value,
    s.payment_total_value,

    -- Razlika izmedu plaćanja i vrijednosti narudžbe
    CASE
        WHEN s.item_count > 0
        AND s.payment_total_value IS NOT NULL
        THEN ROUND(
            s.payment_total_value - s.order_total_value,
            2
        )
        ELSE NULL
    END,

    -- Indikator neslaganja plaćanja
    CASE
        WHEN s.item_count > 0
        AND s.payment_total_value IS NOT NULL
        THEN ABS(
            s.payment_total_value - s.order_total_value
        ) > 0.01
        ELSE FALSE
    END,

    -- Trajanja i vremenski indikatori
    s.approval_time_hours,
    s.carrier_wait_days,
    s.shipping_time_days,
    s.delivery_time_days,
    s.delivery_delay_days,
    s.delivered_within_deadline,
    s.timeline_anomaly_flag,

    -- IQR indikator vrijednosti narudžbe
    (
        s.order_total_value <
            s.order_value_q1
            - 1.5 * (s.order_value_q3 - s.order_value_q1)
        OR
        s.order_total_value >
            s.order_value_q3
            + 1.5 * (s.order_value_q3 - s.order_value_q1)
    ),

    -- IQR indikator trajanja dostave
    CASE
        WHEN s.delivery_time_days IS NOT NULL
         AND s.delivery_time_days >= 0
         AND s.delivery_q1 IS NOT NULL
         AND s.delivery_q3 IS NOT NULL
        THEN (
            s.delivery_time_days <
                s.delivery_q1
                - 1.5 * (s.delivery_q3 - s.delivery_q1)
            OR
            s.delivery_time_days >
                s.delivery_q3
                + 1.5 * (s.delivery_q3 - s.delivery_q1)
        )
        ELSE NULL
    END,

    -- Statistike vrijednosti narudžbe
    ROUND(s.order_value_mean, 4),
    ROUND(s.order_value_median::NUMERIC, 4),
    ROUND(s.order_value_stddev, 4),

    ROUND(
        s.order_total_value - s.order_value_mean,
        4
    ),

    s.order_value_quartile,
    ROUND(s.order_value_percentile::NUMERIC, 6),

    s.group_size,

    (
        s.group_size >= 2
        AND COALESCE(s.order_value_stddev > 0, FALSE)
    )

FROM scored_orders s;

COMMIT;

-- 3. PUNJENJE FACT_PAYMENTS
-- Granulacija: jedno plaćanje unutar narudžbe
-- Prirodni identifikator: (order_id, payment_sequential)
--
-- Statistički indikatori kvalitete podataka preuzimaju se
-- iz staging.payments, gdje su prethodno izračunati.


BEGIN;

INSERT INTO dw.fact_payments (
    purchase_date_key,
    purchase_time_key,
    customer_key,
    payment_type_key,
    order_id,
    payment_sequential,
    payment_value,
    payment_installments,
    zero_payment_flag,
    nonpositive_installments_flag,
    payment_sequence_anomaly_flag,
    payment_outlier_flag
)

SELECT
    -- Datum kupnje narudžbe
    COALESCE(
        TO_CHAR(
            o.order_purchase_timestamp,
            'YYYYMMDD'
        )::INTEGER,
        0
    ) AS purchase_date_key,

    -- Vrijeme kupnje: minute od ponoci + 1
    COALESCE(
        EXTRACT(
            HOUR FROM o.order_purchase_timestamp
        )::INTEGER * 60
        +
        EXTRACT(
            MINUTE FROM o.order_purchase_timestamp
        )::INTEGER
        + 1,
        0
    ) AS purchase_time_key,

    -- Dimenzija kupca
    dc.customer_key,

    -- Dimenzija vrste plaćanja
    dpt.payment_type_key,

    -- Identifikator narudžbe
    p.order_id,

    -- Redni broj plaćanja
    p.payment_sequential,

    -- Iznos plaćanja
    p.payment_value,

    -- Broj rata
    p.payment_installments,

    -- Indikator plaćanja nulte vrijednosti
    p.payment_value_zero,

    -- Indikator nepozitivnog broja rata
    p.installments_nonpositive,

    -- Indikator anomalije redoslijeda plaćanja
    p.payment_sequence_anomaly,

    -- Indikator odstupajuće vrijednosti plaćanja
    p.payment_value_outlier

FROM staging.payments p

-- Povezivanje plaćanja s narudžbom
JOIN staging.orders o
    ON o.order_id = p.order_id

-- Dohvaćanje surogatnog ključa kupca
JOIN dw.dim_customer dc
    ON dc.customer_id = o.customer_id

-- Dohvaćanje surogatnog ključa vrste plaćanja
JOIN dw.dim_payment_type dpt
    ON dpt.payment_type = p.payment_type;

COMMIT;

-- 4. PUNJENJE FACT_REVIEWS
-- Granulacija: jedna recenzija po narudžbi


BEGIN;

INSERT INTO dw.fact_reviews (
    customer_key,
    order_status_key,
    purchase_date_key,
    purchase_time_key,
    review_creation_date_key,
    review_creation_time_key,
    review_answer_date_key,
    review_answer_time_key,
    order_id,
    review_id,
    review_score,
    review_response_time_hours,
    has_review_title,
    has_review_message,
    low_score_flag,
    multiple_reviews_source_flag
)

SELECT
    dc.customer_key,
    dos.order_status_key,

    -- Datum kupnje
    COALESCE(
        TO_CHAR(o.order_purchase_timestamp, 'YYYYMMDD')::INTEGER,
        0
    ),

    -- Vrijeme kupnje
    COALESCE(
        EXTRACT(HOUR FROM o.order_purchase_timestamp)::INTEGER * 60
        + EXTRACT(MINUTE FROM o.order_purchase_timestamp)::INTEGER
        + 1,
        0
    ),

    -- Datum nastanka recenzije
    COALESCE(
        TO_CHAR(r.review_creation_date, 'YYYYMMDD')::INTEGER,
        0
    ),

    -- Vrijeme nastanka recenzije
    COALESCE(
        EXTRACT(HOUR FROM r.review_creation_date)::INTEGER * 60
        + EXTRACT(MINUTE FROM r.review_creation_date)::INTEGER
        + 1,
        0
    ),

    -- Datum odgovora na recenziju
    COALESCE(
        TO_CHAR(r.review_answer_timestamp, 'YYYYMMDD')::INTEGER,
        0
    ),

    -- Vrijeme odgovora
    COALESCE(
        EXTRACT(HOUR FROM r.review_answer_timestamp)::INTEGER * 60
        + EXTRACT(MINUTE FROM r.review_answer_timestamp)::INTEGER
        + 1,
        0
    ),

    r.order_id,
    r.review_id,
    r.review_score,

    -- Trajanje odgovora u satima
    r.review_response_time_hours,

    -- Indikatori sadržaja recenzije
    r.has_review_title,
    r.has_review_message,

    -- Negativna recenzija: ocjena 1 ili 2
    (r.review_score <= 2),

    -- Indikator visestrukih recenzija u izvornim podacima
    r.multiple_reviews_for_order

FROM staging.reviews r

JOIN staging.orders o
    ON o.order_id = r.order_id

JOIN dw.dim_customer dc
    ON dc.customer_id = o.customer_id

JOIN dw.dim_order_status dos
    ON dos.order_status = o.order_status;

COMMIT;

-- 5. PUNJENJE dw.fact_category_month_statistics
--
-- Granulacija:
--   jedna kategorija proizvoda × jedan mjesec kupnje
--
-- Izvor:
--   dw.fact_sales
--   dw.dim_product
--   dw.dim_category
--   dw.dim_date


BEGIN;

WITH sales_base AS (

    SELECT
        fs.sales_key,
        fs.order_id,

        c.category_key,
        md.date_key AS month_date_key,

        fs.product_value,
        fs.freight_value,
        fs.item_total_value,

        fs.free_freight_flag,
        fs.is_outlier_price,
        fs.is_outlier_freight,

        CASE
            WHEN p.product_weight_g > 0
                 AND NOT p.invalid_weight_flag
            THEN p.product_weight_g
            ELSE NULL
        END AS valid_weight_g,

        CASE
            WHEN p.product_volume_cm3 > 0
                 AND NOT p.missing_dimensions_flag
            THEN p.product_volume_cm3
            ELSE NULL
        END AS valid_volume_cm3

    FROM dw.fact_sales fs

    JOIN dw.dim_product p
        ON p.product_key = fs.product_key

    JOIN dw.dim_category c
        ON c.category_name_portuguese =
           p.category_name_portuguese

    JOIN dw.dim_date d
        ON d.date_key = fs.purchase_date_key

    JOIN dw.dim_date md
        ON md.full_date = d.month_start_date
),

statistics AS (

    SELECT
        month_date_key,
        category_key,

        -- Osnovni pokazatelji prodaje

        COUNT(*)::INTEGER AS sales_item_count,

        COUNT(DISTINCT order_id)::INTEGER AS order_count,

        SUM(product_value) AS product_value_sum,

        SUM(freight_value) AS freight_value_sum,

        SUM(item_total_value) AS item_total_value_sum,

        COUNT(*) FILTER (
            WHERE free_freight_flag
        )::INTEGER AS free_freight_item_count,

        COUNT(*) FILTER (
            WHERE is_outlier_price
        )::INTEGER AS price_outlier_count,

        COUNT(*) FILTER (
            WHERE is_outlier_freight
        )::INTEGER AS freight_outlier_count,

        -- Statistika cijena

        AVG(product_value) AS price_mean,

        PERCENTILE_CONT(0.5)
            WITHIN GROUP (ORDER BY product_value)
            AS price_median,

        STDDEV_SAMP(product_value) AS price_stddev,

        MIN(product_value) AS price_min,

        MAX(product_value) AS price_max,

        PERCENTILE_CONT(0.25)
            WITHIN GROUP (ORDER BY product_value)
            AS price_q1,

        PERCENTILE_CONT(0.75)
            WITHIN GROUP (ORDER BY product_value)
            AS price_q3,

        -- Statistika dostave

        AVG(freight_value) AS freight_mean,

        PERCENTILE_CONT(0.5)
            WITHIN GROUP (ORDER BY freight_value)
            AS freight_median,

        STDDEV_SAMP(freight_value) AS freight_stddev,

        MIN(freight_value) AS freight_min,

        MAX(freight_value) AS freight_max,

        PERCENTILE_CONT(0.25)
            WITHIN GROUP (ORDER BY freight_value)
            AS freight_q1,

        PERCENTILE_CONT(0.75)
            WITHIN GROUP (ORDER BY freight_value)
            AS freight_q3,

        -- Pearsonove korelacije

        CORR(
            product_value::DOUBLE PRECISION,
            freight_value::DOUBLE PRECISION
        ) AS price_freight_correlation,

        COUNT(*) FILTER (
            WHERE product_value IS NOT NULL
              AND freight_value IS NOT NULL
        )::INTEGER AS price_freight_n,

        CORR(
            valid_weight_g,
            freight_value::DOUBLE PRECISION
        ) AS weight_freight_correlation,

        COUNT(*) FILTER (
            WHERE valid_weight_g IS NOT NULL
              AND freight_value IS NOT NULL
        )::INTEGER AS weight_freight_n,

        CORR(
            valid_volume_cm3,
            freight_value::DOUBLE PRECISION
        ) AS volume_freight_correlation,

        COUNT(*) FILTER (
            WHERE valid_volume_cm3 IS NOT NULL
              AND freight_value IS NOT NULL
        )::INTEGER AS volume_freight_n

    FROM sales_base

    GROUP BY
        month_date_key,
        category_key
)

INSERT INTO dw.fact_category_month_statistics (

    month_date_key,
    category_key,

    sales_item_count,
    order_count,

    product_value_sum,
    freight_value_sum,
    item_total_value_sum,

    free_freight_item_count,
    price_outlier_count,
    freight_outlier_count,

    price_mean,
    price_median,
    price_stddev,
    price_min,
    price_max,
    price_q1,
    price_q3,
    price_iqr,

    freight_mean,
    freight_median,
    freight_stddev,
    freight_min,
    freight_max,
    freight_q1,
    freight_q3,
    freight_iqr,

    price_freight_correlation,
    price_freight_n,
    price_freight_correlation_valid,

    weight_freight_correlation,
    weight_freight_n,
    weight_freight_correlation_valid,

    volume_freight_correlation,
    volume_freight_n,
    volume_freight_correlation_valid

)

SELECT
    month_date_key,
    category_key,

    sales_item_count,
    order_count,

    product_value_sum,
    freight_value_sum,
    item_total_value_sum,

    free_freight_item_count,
    price_outlier_count,
    freight_outlier_count,

    price_mean,
    price_median,
    price_stddev,
    price_min,
    price_max,
    price_q1,
    price_q3,

    price_q3 - price_q1 AS price_iqr,

    freight_mean,
    freight_median,
    freight_stddev,
    freight_min,
    freight_max,
    freight_q1,
    freight_q3,

    freight_q3 - freight_q1 AS freight_iqr,

    CASE
        WHEN price_freight_n >= 2
             AND price_freight_correlation IS NOT NULL
        THEN price_freight_correlation
        ELSE NULL
    END,

    price_freight_n,

    (
        price_freight_n >= 50
        AND price_freight_correlation IS NOT NULL
    ),

    CASE
        WHEN weight_freight_n >= 2
             AND weight_freight_correlation IS NOT NULL
        THEN weight_freight_correlation
        ELSE NULL
    END,

    weight_freight_n,

    (
        weight_freight_n >= 50
        AND weight_freight_correlation IS NOT NULL
    ),

    CASE
        WHEN volume_freight_n >= 2
             AND volume_freight_correlation IS NOT NULL
        THEN volume_freight_correlation
        ELSE NULL
    END,

    volume_freight_n,

    (
        volume_freight_n >= 50
        AND volume_freight_correlation IS NOT NULL
    )

FROM statistics

ORDER BY
    month_date_key,
    category_key;

COMMIT;
