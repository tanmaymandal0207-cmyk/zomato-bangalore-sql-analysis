-- =============================================================================
-- A13 | Most-liked dishes
-- =============================================================================
-- Business question
--   Menu planning: which dishes do customers single out most often, and do the
--   restaurants known for them rate above other restaurants with dish data?
--
-- Requirements
--   - Split dish_liked into single dishes; count restaurants per dish (not listings).
--   - Top 15 dishes by restaurants, with % of restaurants that have dish data,
--     average rating and average cost for two of those restaurants, and the rating
--     gap vs all restaurants with dish data.
--
-- Grain & rules
--   - Restaurant = distinct URL path (restaurant_id); latest snapshot by votes.
--   - dish_liked comes from the snapshot row; restaurants without dish data are excluded.
--   - Dishes are matched case-insensitively after TRIM; the display name is the
--     alphabetically first spelling (deterministic).
--   - Restaurants with dish data are mostly popular ones, so ratings are compared with
--     the average of restaurants that HAVE dish data, not with the whole city.
--
-- Result : results/a13_most_liked_dishes.csv
-- =============================================================================

WITH restaurants AS (                       -- one row per restaurant (see 03_validation/02)
    SELECT
        REGEXP_EXTRACT(url, r'^[^?]+')                                 AS restaurant_id,
        dish_liked,
        approx_cost_cleaned                                            AS cost_for_two,
        SAFE_CAST(SPLIT(rate_cleaned, '/')[SAFE_OFFSET(0)] AS FLOAT64) AS rating
    FROM `zomatoanalytics.Zomato_csv.restaurants_clean`
    WHERE url IS NOT NULL
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY REGEXP_EXTRACT(url, r'^[^?]+')
        ORDER BY votes_cleaned DESC, url
    ) = 1
),
dishes AS (                                -- one row per restaurant x dish
    SELECT
        r.restaurant_id,
        LOWER(TRIM(d))                                                 AS dish_key,
        MIN(TRIM(d))                                                   AS dish,
        ANY_VALUE(r.cost_for_two)                                      AS cost_for_two,
        ANY_VALUE(r.rating)                                            AS rating
    FROM restaurants r,
         UNNEST(SPLIT(r.dish_liked, ',')) AS d
    WHERE r.dish_liked IS NOT NULL
      AND TRIM(d) != ''
    GROUP BY r.restaurant_id, dish_key
),
base AS (                                  -- restaurants that have dish data
    SELECT
        COUNT(*)                                                       AS restaurants_with_dishes,
        AVG(rating)                                                    AS avg_rating_with_dishes
    FROM restaurants
    WHERE restaurant_id IN (SELECT restaurant_id FROM dishes)
)
SELECT
    MIN(d.dish)                                                        AS dish,
    COUNT(*)                                                           AS restaurants,
    ROUND(100 * COUNT(*) / ANY_VALUE(b.restaurants_with_dishes), 1)    AS pct_of_restaurants_with_dishes,
    ROUND(AVG(d.rating), 2)                                            AS avg_rating,
    ROUND(AVG(d.rating) - ANY_VALUE(b.avg_rating_with_dishes), 2)      AS rating_vs_dish_restaurants,
    ROUND(AVG(d.cost_for_two), 0)                                      AS avg_cost_for_two
FROM dishes d
CROSS JOIN base b
GROUP BY d.dish_key
ORDER BY restaurants DESC, dish
LIMIT 15;
