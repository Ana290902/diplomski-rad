-- Učitavanje očišćenih Olist CSV datoteka u staging sloj
--
-- Izvor:
-- C:/Users/Ana/Desktop/diplomskiPrakticni/data/clean/
--
-- Skripta se pokreće pomoću psql-a.


-- 1. CUSTOMERS
\copy staging.customers FROM 'C:/Users/Ana/Desktop/diplomskiPrakticni/data/clean/olist_customers_dataset_clean.csv' WITH (FORMAT CSV, HEADER TRUE, DELIMITER ',', ENCODING 'UTF8');


-- 2. GEOLOCATION
\copy staging.geolocation FROM 'C:/Users/Ana/Desktop/diplomskiPrakticni/data/clean/olist_geolocation_dataset_clean.csv' WITH (FORMAT CSV, HEADER TRUE, DELIMITER ',', ENCODING 'UTF8');


-- 3. SELLERS
\copy staging.sellers FROM 'C:/Users/Ana/Desktop/diplomskiPrakticni/data/clean/olist_sellers_dataset_clean.csv' WITH (FORMAT CSV, HEADER TRUE, DELIMITER ',', ENCODING 'UTF8');


-- 4. PRODUCTS
\copy staging.products FROM 'C:/Users/Ana/Desktop/diplomskiPrakticni/data/clean/olist_products_dataset_clean.csv' WITH (FORMAT CSV, HEADER TRUE, DELIMITER ',', ENCODING 'UTF8');


-- 5. CATEGORY TRANSLATION
\copy staging.category_translation FROM 'C:/Users/Ana/Desktop/diplomskiPrakticni/data/clean/product_category_name_translation_clean.csv' WITH (FORMAT CSV, HEADER TRUE, DELIMITER ',', ENCODING 'UTF8');


-- 6. ORDERS
\copy staging.orders FROM 'C:/Users/Ana/Desktop/diplomskiPrakticni/data/clean/olist_orders_dataset_clean.csv' WITH (FORMAT CSV, HEADER TRUE, DELIMITER ',', ENCODING 'UTF8');


-- 7. ORDER ITEMS
\copy staging.order_items FROM 'C:/Users/Ana/Desktop/diplomskiPrakticni/data/clean/olist_order_items_dataset_clean.csv' WITH (FORMAT CSV, HEADER TRUE, DELIMITER ',', ENCODING 'UTF8');


-- 8. PAYMENTS
\copy staging.payments FROM 'C:/Users/Ana/Desktop/diplomskiPrakticni/data/clean/olist_order_payments_dataset_clean.csv' WITH (FORMAT CSV, HEADER TRUE, DELIMITER ',', ENCODING 'UTF8');


-- 9. REVIEWS
\copy staging.reviews FROM 'C:/Users/Ana/Desktop/diplomskiPrakticni/data/clean/olist_order_reviews_dataset_clean.csv' WITH (FORMAT CSV, HEADER TRUE, DELIMITER ',', ENCODING 'UTF8');