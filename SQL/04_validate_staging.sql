-- Validacija staging sloja prije izgradnje DW-a
--
-- Sve provjere vraćaju se u jednom rezultatu.
--
-- PASS = provjera je uspješna
-- INFO = informativna karakteristika podataka, nije pogreška

WITH validation AS (

    -- 1. BROJ REDAKA

    SELECT
        'Row count - customers' AS check_name,
        COUNT(*)::BIGINT AS actual_value,
        99441::BIGINT AS expected_value,
        'CHECK' AS check_type
    FROM staging.customers

    UNION ALL
    SELECT 'Row count - geolocation', COUNT(*), 738332, 'CHECK'
    FROM staging.geolocation

    UNION ALL
    SELECT 'Row count - sellers', COUNT(*), 3095, 'CHECK'
    FROM staging.sellers

    UNION ALL
    SELECT 'Row count - products', COUNT(*), 32951, 'CHECK'
    FROM staging.products

    UNION ALL
    SELECT 'Row count - category_translation', COUNT(*), 74, 'CHECK'
    FROM staging.category_translation

    UNION ALL
    SELECT 'Row count - orders', COUNT(*), 99441, 'CHECK'
    FROM staging.orders

    UNION ALL
    SELECT 'Row count - order_items', COUNT(*), 112650, 'CHECK'
    FROM staging.order_items

    UNION ALL
    SELECT 'Row count - payments', COUNT(*), 103886, 'CHECK'
    FROM staging.payments

    UNION ALL
    SELECT 'Row count - reviews', COUNT(*), 98673, 'CHECK'
    FROM staging.reviews


    -- 2. REFERENCIJALNI INTEGRITET

    UNION ALL

    SELECT
        'Orders without customer',
        COUNT(*),
        0,
        'CHECK'
    FROM staging.orders o
    LEFT JOIN staging.customers c
        ON o.customer_id = c.customer_id
    WHERE c.customer_id IS NULL

    UNION ALL

    SELECT
        'Order items without order',
        COUNT(*),
        0,
        'CHECK'
    FROM staging.order_items oi
    LEFT JOIN staging.orders o
        ON oi.order_id = o.order_id
    WHERE o.order_id IS NULL

    UNION ALL

    SELECT
        'Order items without product',
        COUNT(*),
        0,
        'CHECK'
    FROM staging.order_items oi
    LEFT JOIN staging.products p
        ON oi.product_id = p.product_id
    WHERE p.product_id IS NULL

    UNION ALL

    SELECT
        'Order items without seller',
        COUNT(*),
        0,
        'CHECK'
    FROM staging.order_items oi
    LEFT JOIN staging.sellers s
        ON oi.seller_id = s.seller_id
    WHERE s.seller_id IS NULL

    UNION ALL

    SELECT
        'Payments without order',
        COUNT(*),
        0,
        'CHECK'
    FROM staging.payments p
    LEFT JOIN staging.orders o
        ON p.order_id = o.order_id
    WHERE o.order_id IS NULL

    UNION ALL

    SELECT
        'Reviews without order',
        COUNT(*),
        0,
        'CHECK'
    FROM staging.reviews r
    LEFT JOIN staging.orders o
        ON r.order_id = o.order_id
    WHERE o.order_id IS NULL


    -- 3. DOMENSKA I POSLOVNA PRAVILA

    UNION ALL

    SELECT
        'Nonpositive item prices',
        COUNT(*),
        0,
        'CHECK'
    FROM staging.order_items
    WHERE price <= 0

    UNION ALL

    SELECT
        'Negative freight values',
        COUNT(*),
        0,
        'CHECK'
    FROM staging.order_items
    WHERE freight_value < 0

    UNION ALL

    SELECT
        'Invalid item total values',
        COUNT(*),
        0,
        'CHECK'
    FROM staging.order_items
    WHERE item_total_value <> price + freight_value

    UNION ALL

    SELECT
        'Negative payment values',
        COUNT(*),
        0,
        'CHECK'
    FROM staging.payments
    WHERE payment_value < 0

    UNION ALL

    SELECT
        'Invalid review scores',
        COUNT(*),
        0,
        'CHECK'
    FROM staging.reviews
    WHERE review_score NOT BETWEEN 1 AND 5

    UNION ALL

    SELECT
        'Products without clean category',
        COUNT(*),
        0,
        'CHECK'
    FROM staging.products
    WHERE product_category_name_clean IS NULL
       OR product_category_name_english IS NULL

    UNION ALL

    SELECT
        'Inconsistent timeline flags',
        COUNT(*),
        0,
        'CHECK'
    FROM staging.orders
    WHERE has_timeline_anomaly <>
          (
              approval_before_purchase
              OR carrier_before_approval
              OR customer_before_carrier
              OR delivery_before_purchase
          )


    -- 4. INFORMATIVNE KARAKTERISTIKE PODATAKA
    -- Ne predstavljaju pogreške.

    UNION ALL

    SELECT
        'Free freight items',
        COUNT(*),
        NULL::BIGINT,
        'INFO'
    FROM staging.order_items
    WHERE free_freight IS TRUE

    UNION ALL

    SELECT
        'Price outliers',
        COUNT(*),
        NULL,
        'INFO'
    FROM staging.order_items
    WHERE price_outlier IS TRUE

    UNION ALL

    SELECT
        'Freight outliers',
        COUNT(*),
        NULL,
        'INFO'
    FROM staging.order_items
    WHERE freight_outlier IS TRUE

    UNION ALL

    SELECT
        'Orders with timeline anomaly',
        COUNT(*),
        NULL,
        'INFO'
    FROM staging.orders
    WHERE has_timeline_anomaly IS TRUE

    UNION ALL

    SELECT
        'Zero payment rows',
        COUNT(*),
        NULL,
        'INFO'
    FROM staging.payments
    WHERE payment_value_zero IS TRUE

    UNION ALL

    SELECT
        'Orders with payment mismatch',
        COUNT(DISTINCT order_id),
        NULL,
        'INFO'
    FROM staging.payments
    WHERE payment_amount_mismatch IS TRUE

    UNION ALL

    SELECT
        'Products with missing category',
        COUNT(*),
        NULL,
        'INFO'
    FROM staging.products
    WHERE missing_category IS TRUE

    UNION ALL

    SELECT
        'Orders with multiple source reviews',
        COUNT(*),
        NULL,
        'INFO'
    FROM staging.reviews
    WHERE multiple_reviews_for_order IS TRUE
)

SELECT
    check_name,
    actual_value,
    expected_value,
    CASE
        WHEN check_type = 'INFO'
            THEN 'INFO'
        WHEN actual_value = expected_value
            THEN 'PASS'
        ELSE 'FAIL'
    END AS status
FROM validation
ORDER BY
    CASE
        WHEN check_type = 'CHECK'
             AND actual_value <> expected_value THEN 1
        WHEN check_type = 'CHECK' THEN 2
        ELSE 3
    END,
    check_name;
