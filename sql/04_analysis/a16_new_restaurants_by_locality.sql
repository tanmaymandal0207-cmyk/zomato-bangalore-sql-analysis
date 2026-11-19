-- =============================================================================
-- A16 | New restaurants by locality
-- =============================================================================
-- Business question
--   Where is the restaurant market growing? Restaurants marked NEW have no rating
--   yet, which is the best proxy for recent openings in this snapshot.
--
-- Requirements
--   - Localities with at least 100 restaurants, plus a city row.
--   - Restaurants, NEW restaurants, % NEW, and % of NEW restaurants taking online orders.
--   - City row first, then the top 10 localities by % NEW (ties by count).
--
-- Grain & rules
--   - Restaurant = distinct URL path (restaurant_id); latest snapshot by votes.
--   - NEW = rate_cleaned = 'NEW' on the snapshot row. '-' and NULL ratings are not NEW.
--   - NEW is a proxy for recently opened: the scrape has no opening date.
--
-- Result : results/a16_new_restaurants_by_locality.csv
-- =============================================================================

WITH restaurants AS (                       -- one row per restaurant (see 03_validation/02)
    SELECT
        REGEXP_EXTRACT(url, r'^[^?]+')                                 AS restaurant_id,
        location,
        online_order,
        rate_cleaned
    FROM `zomatoanalytics.Zomato_csv.restaurants_clean`
    WHERE url IS NOT NULL
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY REGEXP_EXTRACT(url, r'^[^?]+')
        ORDER BY votes_cleaned DESC, url
    ) = 1
),
scoped AS (
    SELECT location AS scope, online_order, rate_cleaned FROM restaurants WHERE location IS NOT NULL
    UNION ALL
    SELECT 'ALL BANGALORE', online_order, rate_cleaned FROM restaurants
),
summary AS (
    SELECT
        scope,
        COUNT(*)                                                       AS restaurants,
        COUNTIF(rate_cleaned = 'NEW')                                  AS new_restaurants,
        COUNTIF(rate_cleaned = 'NEW' AND online_order = 'Yes')         AS new_online
    FROM scoped
    GROUP BY scope
    HAVING COUNT(*) >= 100
),
ranked AS (
    SELECT *,
        ROW_NUMBER() OVER (ORDER BY scope = 'ALL BANGALORE' DESC,
                                    SAFE_DIVIDE(new_restaurants, restaurants) DESC,
                                    new_restaurants DESC, scope)       AS rnk
    FROM summary
)
SELECT
    scope,
    restaurants,
    new_restaurants,
    ROUND(100 * SAFE_DIVIDE(new_restaurants, restaurants), 1)          AS pct_new,
    ROUND(100 * SAFE_DIVIDE(new_online, new_restaurants), 1)           AS pct_new_with_online_ordering
FROM ranked
WHERE rnk <= 11
ORDER BY rnk;
