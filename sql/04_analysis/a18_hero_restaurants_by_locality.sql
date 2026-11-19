-- =============================================================================
-- A18 | Hero restaurants by locality
-- =============================================================================
-- Business question
--   For a flagship dining guide or premium partner programme: where are the
--   'hero' restaurants, rated 4.5+ by 1,000+ voters, concentrated?
--
-- Requirements
--   - Hero = rating >= 4.5 AND votes >= 1,000.
--   - Per locality: restaurants, heroes, heroes per 100 restaurants, and the hero
--     with the most votes.
--   - City row first, then the top 10 localities by heroes (ties by density).
--
-- Grain & rules
--   - Restaurant = distinct URL path (restaurant_id); latest snapshot by votes.
--   - Each outlet counts separately (two outlets of one brand = two heroes).
--   - Top hero ties break by restaurant_id.
--
-- Result : results/a18_hero_restaurants_by_locality.csv
-- =============================================================================

WITH restaurants AS (                       -- one row per restaurant (see 03_validation/02)
    SELECT
        REGEXP_EXTRACT(url, r'^[^?]+')                                 AS restaurant_id,
        name,
        location,
        COALESCE(votes_cleaned, 0)                                     AS votes,
        SAFE_CAST(SPLIT(rate_cleaned, '/')[SAFE_OFFSET(0)] AS FLOAT64) AS rating
    FROM `zomatoanalytics.Zomato_csv.restaurants_clean`
    WHERE url IS NOT NULL
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY REGEXP_EXTRACT(url, r'^[^?]+')
        ORDER BY votes_cleaned DESC, url
    ) = 1
),
scoped AS (
    SELECT location AS scope, restaurant_id, name, votes, rating FROM restaurants WHERE location IS NOT NULL
    UNION ALL
    SELECT 'ALL BANGALORE', restaurant_id, name, votes, rating FROM restaurants
),
summary AS (
    SELECT
        scope,
        COUNT(*)                                                       AS restaurants,
        COUNTIF(rating >= 4.5 AND votes >= 1000)                       AS heroes,
        ARRAY_AGG(name ORDER BY IFNULL(rating >= 4.5 AND votes >= 1000, FALSE) DESC,
                                votes DESC, restaurant_id LIMIT 1)     AS top_hero   -- heroes sort first
    FROM scoped
    GROUP BY scope
),
ranked AS (
    SELECT *,
        ROW_NUMBER() OVER (ORDER BY scope = 'ALL BANGALORE' DESC, heroes DESC,
                                    SAFE_DIVIDE(heroes, restaurants) DESC, scope) AS rnk
    FROM summary
    WHERE heroes > 0
)
SELECT
    scope,
    restaurants,
    heroes,
    ROUND(100 * SAFE_DIVIDE(heroes, restaurants), 1)                   AS heroes_per_100_restaurants,
    top_hero[SAFE_OFFSET(0)]                                           AS top_hero_by_votes
FROM ranked
WHERE rnk <= 11
ORDER BY rnk;
