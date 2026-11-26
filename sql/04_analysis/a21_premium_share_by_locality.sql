-- =============================================================================
-- A21 | Premium share by locality
-- =============================================================================
-- Business question
--   Where should a premium (Rs 1,000+ for two) restaurant open? Which large
--   localities already have a premium-heavy mix, and how do premium places rate there?
--
-- Requirements
--   - Localities with at least 200 restaurants that list a cost.
--   - Restaurants with cost, premium restaurants (cost >= 1,000), premium share,
--     average rating of premium vs non-premium restaurants.
--   - Highest premium share first.
--
-- Grain & rules
--   - Restaurant = distinct URL path (restaurant_id); latest snapshot by votes.
--   - Restaurants without a cost are excluded.
--
-- Result : results/a21_premium_share_by_locality.csv
-- =============================================================================

WITH restaurants AS (                       -- one row per restaurant (see 03_validation/02)
    SELECT
        REGEXP_EXTRACT(url, r'^[^?]+')                                 AS restaurant_id,
        location,
        approx_cost_cleaned                                            AS cost_for_two,
        SAFE_CAST(SPLIT(rate_cleaned, '/')[SAFE_OFFSET(0)] AS FLOAT64) AS rating
    FROM `zomatoanalytics.Zomato_csv.restaurants_clean`
    WHERE url IS NOT NULL
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY REGEXP_EXTRACT(url, r'^[^?]+')
        ORDER BY votes_cleaned DESC, url
    ) = 1
)
SELECT
    location,
    COUNT(*)                                                           AS restaurants_with_cost,
    COUNTIF(cost_for_two >= 1000)                                      AS premium_restaurants,
    ROUND(100 * COUNTIF(cost_for_two >= 1000) / COUNT(*), 1)           AS premium_share_pct,
    ROUND(AVG(IF(cost_for_two >= 1000, rating, NULL)), 2)              AS avg_rating_premium,
    ROUND(AVG(IF(cost_for_two <  1000, rating, NULL)), 2)              AS avg_rating_other
FROM restaurants
WHERE location IS NOT NULL
  AND cost_for_two IS NOT NULL
GROUP BY location
HAVING COUNT(*) >= 200
ORDER BY premium_share_pct DESC, location;
