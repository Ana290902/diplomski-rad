-- Validacija dimenzijskih tablica

WITH validation AS (

    -- DIM_DATE

    SELECT
        'CHECK' AS check_type,
        'dim_date - exactly one Unknown row' AS check_name,
        CASE
            WHEN COUNT(*) = 1 THEN 'PASS'
            ELSE 'FAIL'
        END AS result,
        COUNT(*)::TEXT AS details
    FROM dw.dim_date
    WHERE is_unknown = TRUE

    UNION ALL

    SELECT
        'CHECK',
        'dim_date - Unknown has key 0',
        CASE
            WHEN COUNT(*) = 1 THEN 'PASS'
            ELSE 'FAIL'
        END,
        COUNT(*)::TEXT
    FROM dw.dim_date
    WHERE date_key = 0
      AND is_unknown = TRUE

    UNION ALL

    SELECT
        'CHECK',
        'dim_date - no duplicate full dates',
        CASE
            WHEN COUNT(*) = 0 THEN 'PASS'
            ELSE 'FAIL'
        END,
        COUNT(*)::TEXT
    FROM (
        SELECT full_date
        FROM dw.dim_date
        WHERE is_unknown = FALSE
        GROUP BY full_date
        HAVING COUNT(*) > 1
    ) x

    UNION ALL

    SELECT
        'CHECK',
        'dim_date - continuous calendar',
        CASE
            WHEN COUNT(*) =
                 (MAX(full_date) - MIN(full_date) + 1)
                THEN 'PASS'
            ELSE 'FAIL'
        END,
        COUNT(*)::TEXT || ' dates'
    FROM dw.dim_date
    WHERE is_unknown = FALSE


    -- DIM_TIME

    UNION ALL

    SELECT
        'CHECK',
        'dim_time - 1441 rows',
        CASE
            WHEN COUNT(*) = 1441 THEN 'PASS'
            ELSE 'FAIL'
        END,
        COUNT(*)::TEXT
    FROM dw.dim_time

    UNION ALL

    SELECT
        'CHECK',
        'dim_time - exactly one Unknown row',
        CASE
            WHEN COUNT(*) = 1 THEN 'PASS'
            ELSE 'FAIL'
        END,
        COUNT(*)::TEXT
    FROM dw.dim_time
    WHERE is_unknown = TRUE

    UNION ALL

    SELECT
        'CHECK',
        'dim_time - 1440 real minutes',
        CASE
            WHEN COUNT(*) = 1440 THEN 'PASS'
            ELSE 'FAIL'
        END,
        COUNT(*)::TEXT
    FROM dw.dim_time
    WHERE is_unknown = FALSE

    UNION ALL

    SELECT
        'CHECK',
        'dim_time - no duplicate real times',
        CASE
            WHEN COUNT(*) = 0 THEN 'PASS'
            ELSE 'FAIL'
        END,
        COUNT(*)::TEXT
    FROM (
        SELECT full_time
        FROM dw.dim_time
        WHERE is_unknown = FALSE
        GROUP BY full_time
        HAVING COUNT(*) > 1
    ) x

    UNION ALL

    SELECT
        'CHECK',
        'dim_time - part_of_day consistent',
        CASE
            WHEN COUNT(*) = 0 THEN 'PASS'
            ELSE 'FAIL'
        END,
        COUNT(*)::TEXT || ' inconsistent rows'
    FROM dw.dim_time
    WHERE is_unknown = FALSE
      AND (
          (hour_number BETWEEN 0 AND 5
              AND part_of_day <> 'night')
       OR (hour_number BETWEEN 6 AND 11
              AND part_of_day <> 'morning')
       OR (hour_number BETWEEN 12 AND 17
              AND part_of_day <> 'afternoon')
       OR (hour_number BETWEEN 18 AND 23
              AND part_of_day <> 'evening')
      )

    UNION ALL

    SELECT
        'CHECK',
        'dim_time - business hours consistent',
        CASE
            WHEN COUNT(*) = 0 THEN 'PASS'
            ELSE 'FAIL'
        END,
        COUNT(*)::TEXT || ' inconsistent rows'
    FROM dw.dim_time
    WHERE is_unknown = FALSE
      AND is_business_hours <>
          (hour_number BETWEEN 8 AND 16)


    -- DIM_CUSTOMER

    UNION ALL

    SELECT
        'CHECK',
        'dim_customer - row count matches staging',
        CASE
            WHEN
                (SELECT COUNT(*) FROM dw.dim_customer)
                =
                (SELECT COUNT(*) FROM staging.customers)
            THEN 'PASS'
            ELSE 'FAIL'
        END,
        (SELECT COUNT(*) FROM dw.dim_customer)::TEXT
    FROM (SELECT 1) x

    UNION ALL

    SELECT
        'CHECK',
        'dim_customer - all source customers represented',
        CASE
            WHEN COUNT(*) = 0 THEN 'PASS'
            ELSE 'FAIL'
        END,
        COUNT(*)::TEXT || ' missing'
    FROM staging.customers s
    LEFT JOIN dw.dim_customer d
        ON d.customer_id = s.customer_id
    WHERE d.customer_key IS NULL


    -- DIM_SELLER

    UNION ALL

    SELECT
        'CHECK',
        'dim_seller - row count matches staging',
        CASE
            WHEN
                (SELECT COUNT(*) FROM dw.dim_seller)
                =
                (SELECT COUNT(*) FROM staging.sellers)
            THEN 'PASS'
            ELSE 'FAIL'
        END,
        (SELECT COUNT(*) FROM dw.dim_seller)::TEXT
    FROM (SELECT 1) x

    UNION ALL

    SELECT
        'CHECK',
        'dim_seller - all source sellers represented',
        CASE
            WHEN COUNT(*) = 0 THEN 'PASS'
            ELSE 'FAIL'
        END,
        COUNT(*)::TEXT || ' missing'
    FROM staging.sellers s
    LEFT JOIN dw.dim_seller d
        ON d.seller_id = s.seller_id
    WHERE d.seller_key IS NULL


    -- DIM_PRODUCT

    UNION ALL

    SELECT
        'CHECK',
        'dim_product - row count matches staging',
        CASE
            WHEN
                (SELECT COUNT(*) FROM dw.dim_product)
                =
                (SELECT COUNT(*) FROM staging.products)
            THEN 'PASS'
            ELSE 'FAIL'
        END,
        (SELECT COUNT(*) FROM dw.dim_product)::TEXT
    FROM (SELECT 1) x

    UNION ALL

    SELECT
        'CHECK',
        'dim_product - all source products represented',
        CASE
            WHEN COUNT(*) = 0 THEN 'PASS'
            ELSE 'FAIL'
        END,
        COUNT(*)::TEXT || ' missing'
    FROM staging.products s
    LEFT JOIN dw.dim_product d
        ON d.product_id = s.product_id
    WHERE d.product_key IS NULL


    -- DIM_CATEGORY

    UNION ALL

    SELECT
        'CHECK',
        'dim_category - all product categories represented',
        CASE
            WHEN COUNT(*) = 0 THEN 'PASS'
            ELSE 'FAIL'
        END,
        COUNT(*)::TEXT || ' missing'
    FROM (
        SELECT DISTINCT product_category_name_clean
        FROM staging.products
    ) s
    LEFT JOIN dw.dim_category d
        ON d.category_name_portuguese =
           s.product_category_name_clean
    WHERE d.category_key IS NULL


    -- DIM_ORDER_STATUS

    UNION ALL

    SELECT
        'CHECK',
        'dim_order_status - all statuses represented',
        CASE
            WHEN COUNT(*) = 0 THEN 'PASS'
            ELSE 'FAIL'
        END,
        COUNT(*)::TEXT || ' missing'
    FROM (
        SELECT DISTINCT order_status
        FROM staging.orders
    ) s
    LEFT JOIN dw.dim_order_status d
        ON d.order_status = s.order_status
    WHERE d.order_status_key IS NULL


    -- DIM_PAYMENT_TYPE

    UNION ALL

    SELECT
        'CHECK',
        'dim_payment_type - all payment types represented',
        CASE
            WHEN COUNT(*) = 0 THEN 'PASS'
            ELSE 'FAIL'
        END,
        COUNT(*)::TEXT || ' missing'
    FROM (
        SELECT DISTINCT payment_type
        FROM staging.payments
    ) s
    LEFT JOIN dw.dim_payment_type d
        ON d.payment_type = s.payment_type
    WHERE d.payment_type_key IS NULL


    -- INFO

    UNION ALL

    SELECT
        'INFO',
        'dim_date - total rows',
        'INFO',
        COUNT(*)::TEXT
    FROM dw.dim_date

    UNION ALL

    SELECT
        'INFO',
        'dim_date - real date range',
        'INFO',
        MIN(full_date)::TEXT || ' to ' ||
        MAX(full_date)::TEXT
    FROM dw.dim_date
    WHERE is_unknown = FALSE

    UNION ALL

    SELECT
        'INFO',
        'dim_category - total rows',
        'INFO',
        COUNT(*)::TEXT
    FROM dw.dim_category

    UNION ALL

    SELECT
        'INFO',
        'dim_order_status - total rows',
        'INFO',
        COUNT(*)::TEXT
    FROM dw.dim_order_status

    UNION ALL

    SELECT
        'INFO',
        'dim_payment_type - total rows',
        'INFO',
        COUNT(*)::TEXT
    FROM dw.dim_payment_type
)

SELECT
    check_type,
    check_name,
    result,
    details
FROM validation
ORDER BY
    CASE check_type
        WHEN 'CHECK' THEN 1
        ELSE 2
    END,
    check_name;