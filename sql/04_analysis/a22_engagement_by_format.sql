-- =============================================================================
-- A22 | Engagement by restaurant format
-- =============================================================================
-- Business question
--   Which restaurant formats earn the most customer engagement per outlet, and
--   which formats have many outlets but little attention?
--
-- Requirements
--   - Format = first value of rest_type; formats with at least 100 restaurants.
--   - Restaurants, % with zero votes, average votes, votes share, average rating.
--   - Highest average votes first.
--
-- Grain & rules
--   - Restaurant = distinct URL path (restaurant_id); latest snapshot by votes.
--   - Restaurants with no rest_type are excluded.
--
-- Result : results/a22_engagement_by_format.csv
-- =============================================================================

WITH restaurants AS (                       -- one row per restaurant (see 03_validation/02)
    SELECT
        REGEXP_EXTRACT(url, r'^[^?]+')                                 AS restaurant_id,
        rest_type,
        COALESCE(votes_cleaned, 0)                                     AS votes,
        SAFE_CAST(SPLIT(rate_cleaned, '/')[SAFE_OFFSET(0)] AS FLOAT64) AS rating
    FROM `zomatoanalytics.Zomato_csv.restaurants_clean`
    WHERE url IS NOT NULL
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY REGEXP_EXTRACT(url, r'^[^?]+')
        ORDER BY votes_cleaned DESC, url
    ) = 1
),
typed AS (
    SELECT TRIM(REGEXP_EXTRACT(rest_type, r'^[^,]+')) AS format, votes, rating
    FROM restaurants
    WHERE rest_type IS NOT NULL
)
SELECT
    format,
    COUNT(*)                                                           AS restaurants,
    ROUND(100 * COUNTIF(votes = 0) / COUNT(*), 1)                      AS pct_zero_votes,
    ROUND(AVG(votes), 0)                                               AS avg_votes,
    ROUND(100 * SUM(votes) / SUM(SUM(votes)) OVER (), 1)               AS pct_of_votes,
    ROUND(AVG(rating), 2)                                              AS avg_rating
FROM typed
GROUP BY format
HAVING COUNT(*) >= 100
ORDER BY avg_votes DESC, format;
