-- =============================================================================
-- A14 | Listing categories (listed_in_type)
-- =============================================================================
-- Business question
--   Zomato lists restaurants under 7 categories (Delivery, Dine-out, Buffet ...).
--   Which categories are crowded, which are premium, and how many restaurants
--   are listed in more than one?
--
-- Requirements
--   - Per category: restaurants, % of all restaurants, restaurants listed ONLY in
--     that category, average rating, average cost for two, % online, % table booking.
--   - Largest category first.
--
-- Grain & rules
--   - Restaurant = distinct URL path (restaurant_id); latest snapshot by votes.
--   - A restaurant can sit in several categories: one row per restaurant x category
--     (listed_in_city duplicates removed), so categories do not add up to 12,453.
--   - Attributes (rating, cost, ordering) come from the restaurant's snapshot row.
--
-- Result : results/a14_listing_categories.csv
-- =============================================================================

WITH restaurants AS (                       -- one row per restaurant (see 03_validation/02)
    SELECT
        REGEXP_EXTRACT(url, r'^[^?]+')                                 AS restaurant_id,
        online_order,
        book_table,
        approx_cost_cleaned                                            AS cost_for_two,
        SAFE_CAST(SPLIT(rate_cleaned, '/')[SAFE_OFFSET(0)] AS FLOAT64) AS rating
    FROM `zomatoanalytics.Zomato_csv.restaurants_clean`
    WHERE url IS NOT NULL
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY REGEXP_EXTRACT(url, r'^[^?]+')
        ORDER BY votes_cleaned DESC, url
    ) = 1
),
categories AS (                             -- restaurant x category, all listing rows
    SELECT DISTINCT
        REGEXP_EXTRACT(url, r'^[^?]+')                                 AS restaurant_id,
        listed_in_type                                                 AS category
    FROM `zomatoanalytics.Zomato_csv.restaurants_clean`
    WHERE url IS NOT NULL
),
per_restaurant AS (
    SELECT restaurant_id, COUNT(*) AS n_categories
    FROM categories
    GROUP BY restaurant_id
)
SELECT
    c.category,
    COUNT(*)                                                           AS restaurants,
    ROUND(100 * COUNT(*) / (SELECT COUNT(*) FROM restaurants), 1)      AS pct_of_all_restaurants,
    COUNTIF(p.n_categories = 1)                                        AS only_in_this_category,
    ROUND(AVG(r.rating), 2)                                            AS avg_rating,
    ROUND(AVG(r.cost_for_two), 0)                                      AS avg_cost_for_two,
    ROUND(100 * COUNTIF(r.online_order = 'Yes') / COUNT(*), 1)         AS pct_online,
    ROUND(100 * COUNTIF(r.book_table = 'Yes') / COUNT(*), 1)           AS pct_table_booking
FROM categories c
JOIN restaurants r USING (restaurant_id)
JOIN per_restaurant p USING (restaurant_id)
GROUP BY c.category
ORDER BY restaurants DESC, c.category;
