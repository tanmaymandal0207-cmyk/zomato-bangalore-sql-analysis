-- =============================================================================
-- A15 | Affordable quality by locality
-- =============================================================================
-- Business question
--   For a budget-dining guide or campaign: which localities have the most
--   restaurants that are both good (rated 4.0+) and affordable (Rs 500 or less
--   for two)?
--
-- Requirements
--   - Localities with at least 100 restaurants.
--   - Rated restaurants, affordable-quality restaurants, their share of rated
--     restaurants, and their average rating and cost.
--   - City row first, then the top 10 localities by count (ties by share).
--
-- Grain & rules
--   - Restaurant = distinct URL path (restaurant_id); latest snapshot by votes.
--   - Rated restaurants only; restaurants with no cost cannot qualify.
--
-- Result : results/a15_affordable_quality_by_locality.csv
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
),
scoped AS (
    SELECT location AS scope, cost_for_two, rating FROM restaurants WHERE location IS NOT NULL
    UNION ALL
    SELECT 'ALL BANGALORE', cost_for_two, rating FROM restaurants
),
big AS (
    SELECT scope FROM scoped GROUP BY scope HAVING COUNT(*) >= 100
),
summary AS (
    SELECT
        s.scope,
        COUNT(s.rating)                                                AS rated_restaurants,
        COUNTIF(s.rating >= 4.0 AND s.cost_for_two <= 500)             AS affordable_quality,
        AVG(IF(s.rating >= 4.0 AND s.cost_for_two <= 500, s.rating, NULL))       AS aq_rating,
        AVG(IF(s.rating >= 4.0 AND s.cost_for_two <= 500, s.cost_for_two, NULL)) AS aq_cost
    FROM scoped s
    JOIN big USING (scope)
    GROUP BY s.scope
),
ranked AS (
    SELECT *,
        ROW_NUMBER() OVER (ORDER BY scope = 'ALL BANGALORE' DESC, affordable_quality DESC,
                                    SAFE_DIVIDE(affordable_quality, rated_restaurants) DESC, scope) AS rnk
    FROM summary
)
SELECT
    scope,
    rated_restaurants,
    affordable_quality,
    ROUND(100 * SAFE_DIVIDE(affordable_quality, rated_restaurants), 1) AS pct_of_rated,
    ROUND(aq_rating, 2)                                                AS avg_rating_affordable_quality,
    ROUND(aq_cost, 0)                                                  AS avg_cost_affordable_quality
FROM ranked
WHERE rnk <= 11
ORDER BY rnk;
