-- =============================================================================
-- A24 | Specialists vs generalists
-- =============================================================================
-- Business question
--   Menu strategy: do restaurants that focus on one or two cuisines rate higher
--   than those that serve many?
--
-- Requirements
--   - Cuisine breadth = number of distinct cuisines a restaurant lists:
--     1, 2, 3, 4, 5+.
--   - Restaurants, rated restaurants, average rating, % rated 4.0+, average cost.
--
-- Grain & rules
--   - Restaurant = distinct URL path (restaurant_id); latest snapshot by votes.
--   - Cuisines split on ',' with TRIM, counted DISTINCT per restaurant.
--   - Restaurants with no cuisines are excluded.
--
-- Result : results/a24_cuisine_breadth_vs_rating.csv
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
breadth AS (
    SELECT
        r.restaurant_id, r.cost_for_two, r.rating,
        (SELECT COUNT(DISTINCT TRIM(c)) FROM UNNEST(SPLIT(r.cuisines, ',')) AS c
         WHERE TRIM(c) != '')                                          AS n_cuisines
    FROM restaurants r
    WHERE r.cuisines IS NOT NULL
)
SELECT
    IF(n_cuisines >= 5, '5+', CAST(n_cuisines AS STRING))              AS cuisines_served,
    COUNT(*)                                                           AS restaurants,
    COUNT(rating)                                                      AS rated_restaurants,
    ROUND(AVG(rating), 2)                                              AS avg_rating,
    ROUND(100 * COUNTIF(rating >= 4.0) / COUNT(rating), 1)             AS pct_rated_4_plus,
    ROUND(AVG(cost_for_two), 0)                                        AS avg_cost_for_two
FROM breadth
WHERE n_cuisines > 0
GROUP BY cuisines_served
ORDER BY cuisines_served;
