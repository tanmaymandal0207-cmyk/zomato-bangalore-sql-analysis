-- =============================================================================
-- A26 | Dormant listings by locality
-- =============================================================================
-- Business question
--   Listing hygiene: where do the most restaurants have zero votes (no customer
--   engagement at all), and how many of those take online orders?
--
-- Requirements
--   - Localities with at least 200 restaurants, plus a city row.
--   - Restaurants, zero-vote restaurants, % zero-vote, % of zero-vote restaurants
--     taking online orders. City first, then highest % zero-vote.
--
-- Grain & rules
--   - Restaurant = distinct URL path (restaurant_id); latest snapshot by votes.
--   - votes_cleaned NULL is treated as 0.
--
-- Result : results/a26_zero_vote_listings_by_locality.csv
-- =============================================================================

WITH restaurants AS (                       -- one row per restaurant (see 03_validation/02)
    SELECT
        REGEXP_EXTRACT(url, r'^[^?]+')                                 AS restaurant_id,
        location,
        online_order,
        COALESCE(votes_cleaned, 0)                                     AS votes
    FROM `zomatoanalytics.Zomato_csv.restaurants_clean`
    WHERE url IS NOT NULL
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY REGEXP_EXTRACT(url, r'^[^?]+')
        ORDER BY votes_cleaned DESC, url
    ) = 1
),
scoped AS (
    SELECT location AS scope, votes, online_order FROM restaurants WHERE location IS NOT NULL
    UNION ALL
    SELECT 'ALL BANGALORE', votes, online_order FROM restaurants
)
SELECT
    scope,
    COUNT(*)                                                           AS restaurants,
    COUNTIF(votes = 0)                                                 AS zero_vote_restaurants,
    ROUND(100 * COUNTIF(votes = 0) / COUNT(*), 1)                      AS pct_zero_vote,
    ROUND(100 * SAFE_DIVIDE(COUNTIF(votes = 0 AND online_order = 'Yes'),
                            COUNTIF(votes = 0)), 1)                    AS pct_zero_vote_with_online
FROM scoped
GROUP BY scope
HAVING COUNT(*) >= 200
ORDER BY scope = 'ALL BANGALORE' DESC, pct_zero_vote DESC, scope;
