-- =============================================================================
-- A17 | Cuisine price positioning
-- =============================================================================
-- Business question
--   Pricing a new menu: which cuisines sit at premium prices and which compete on
--   value, and does a higher price come with a higher rating?
--
-- Requirements
--   - Cuisines served by at least 100 restaurants.
--   - Restaurants, average cost for two, price index vs the city average (1.00 =
--     city average), average rating, and a price tier:
--     Premium (index >= 1.30), Value (index <= 0.80), Mid otherwise.
--   - Most expensive first.
--
-- Grain & rules
--   - Restaurant = distinct URL path (restaurant_id); latest snapshot by votes.
--   - Cuisines split from the multi-valued column, TRIM per value, DISTINCT per
--     restaurant (same method as A05/A06).
--   - City average cost = all restaurants with a cost (restaurant grain).
--   - A restaurant counts in every cuisine it serves.
--
-- Result : results/a17_cuisine_price_positioning.csv
-- =============================================================================

WITH restaurants AS (                       -- one row per restaurant (see 03_validation/02)
    SELECT
        REGEXP_EXTRACT(url, r'^[^?]+')                                 AS restaurant_id,
        cuisines,
        approx_cost_cleaned                                            AS cost_for_two,
        SAFE_CAST(SPLIT(rate_cleaned, '/')[SAFE_OFFSET(0)] AS FLOAT64) AS rating
    FROM `zomatoanalytics.Zomato_csv.restaurants_clean`
    WHERE url IS NOT NULL
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY REGEXP_EXTRACT(url, r'^[^?]+')
        ORDER BY votes_cleaned DESC, url
    ) = 1
),
restaurant_cuisines AS (
    SELECT DISTINCT r.restaurant_id, TRIM(c) AS cuisine, r.cost_for_two, r.rating
    FROM restaurants r,
         UNNEST(SPLIT(r.cuisines, ',')) AS c
    WHERE r.cuisines IS NOT NULL
      AND TRIM(c) != ''
),
city AS (
    SELECT AVG(cost_for_two) AS city_cost FROM restaurants
)
SELECT
    cuisine,
    COUNT(*)                                                           AS restaurants,
    ROUND(AVG(cost_for_two), 0)                                        AS avg_cost_for_two,
    ROUND(AVG(cost_for_two) / ANY_VALUE(ct.city_cost), 2)              AS price_index,
    ROUND(AVG(rating), 2)                                              AS avg_rating,
    CASE
        WHEN AVG(cost_for_two) / ANY_VALUE(ct.city_cost) >= 1.30 THEN 'Premium'
        WHEN AVG(cost_for_two) / ANY_VALUE(ct.city_cost) <= 0.80 THEN 'Value'
        ELSE 'Mid'
    END                                                                AS price_tier
FROM restaurant_cuisines
CROSS JOIN city ct
GROUP BY cuisine
HAVING COUNT(*) >= 100
ORDER BY avg_cost_for_two DESC, cuisine;
