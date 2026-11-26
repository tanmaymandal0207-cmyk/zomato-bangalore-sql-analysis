-- =============================================================================
-- A20 | Rating distribution
-- =============================================================================
-- Business question
--   Quality health check: how are Bangalore restaurants spread across rating bands,
--   and how much customer attention (votes) does each band get?
--
-- Requirements
--   - Bands: below 3.0, 3.0-3.4, 3.5-3.9, 4.0-4.4, 4.5+, plus 'Not rated'.
--   - Restaurants, % of all restaurants, votes, % of all votes, average votes per restaurant.
--
-- Grain & rules
--   - Restaurant = distinct URL path (restaurant_id); latest snapshot by votes.
--   - 'Not rated' = rating NULL (NEW, '-' or missing).
--   - Bands add up to 12,453 restaurants and all votes.
--
-- Result : results/a20_rating_distribution.csv
-- =============================================================================

WITH restaurants AS (                       -- one row per restaurant (see 03_validation/02)
    SELECT
        REGEXP_EXTRACT(url, r'^[^?]+')                                 AS restaurant_id,
        COALESCE(votes_cleaned, 0)                                     AS votes,
        SAFE_CAST(SPLIT(rate_cleaned, '/')[SAFE_OFFSET(0)] AS FLOAT64) AS rating
    FROM `zomatoanalytics.Zomato_csv.restaurants_clean`
    WHERE url IS NOT NULL
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY REGEXP_EXTRACT(url, r'^[^?]+')
        ORDER BY votes_cleaned DESC, url
    ) = 1
),
banded AS (
    SELECT
        votes,
        CASE
            WHEN rating IS NULL THEN '6 Not rated'
            WHEN rating < 3.0   THEN '1 Below 3.0'
            WHEN rating < 3.5   THEN '2 3.0-3.4'
            WHEN rating < 4.0   THEN '3 3.5-3.9'
            WHEN rating < 4.5   THEN '4 4.0-4.4'
            ELSE                     '5 4.5+'
        END                                                            AS band
    FROM restaurants
)
SELECT
    SUBSTR(band, 3)                                                    AS rating_band,
    COUNT(*)                                                           AS restaurants,
    ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)                   AS pct_restaurants,
    SUM(votes)                                                         AS votes,
    ROUND(100 * SUM(votes) / SUM(SUM(votes)) OVER (), 1)               AS pct_votes,
    ROUND(AVG(votes), 0)                                               AS avg_votes
FROM banded
GROUP BY band
ORDER BY band;
