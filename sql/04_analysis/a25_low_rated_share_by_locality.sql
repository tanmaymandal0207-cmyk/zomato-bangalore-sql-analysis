-- =============================================================================
-- A25 | Quality risk: low-rated share by locality
-- =============================================================================
-- Business question
--   Quality assurance: which localities (100+ rated restaurants) have the highest
--   share of poorly rated restaurants (below 3.0)?
--
-- Requirements
--   - Rated restaurants, restaurants rated below 3.0, their share, locality average
--     rating. Top 10 by share.
--
-- Grain & rules
--   - Restaurant = distinct URL path (restaurant_id); latest snapshot by votes.
--   - Rated restaurants only (rating NOT NULL).
--
-- Result : results/a25_low_rated_share_by_locality.csv
-- =============================================================================

WITH restaurants AS (                       -- one row per restaurant (see 03_validation/02)
    SELECT
        REGEXP_EXTRACT(url, r'^[^?]+')                                 AS restaurant_id,
        location,
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
    COUNT(rating)                                                      AS rated_restaurants,
    COUNTIF(rating < 3.0)                                              AS rated_below_3,
    ROUND(100 * COUNTIF(rating < 3.0) / COUNT(rating), 1)              AS pct_below_3,
    ROUND(AVG(rating), 2)                                              AS avg_rating
FROM restaurants
WHERE location IS NOT NULL
GROUP BY location
HAVING COUNT(rating) >= 100
ORDER BY pct_below_3 DESC, location
LIMIT 10;
