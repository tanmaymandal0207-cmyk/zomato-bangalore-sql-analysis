-- =============================================================================
-- A09 | Pareto test: do 20% of restaurants take 80% of votes?
-- =============================================================================
-- Business question
--   Is customer engagement (votes) concentrated in a few restaurants, city-wide
--   and within each locality? Where is it most and least concentrated?
--
-- Requirements
--   - City-wide row plus every locality with at least 50 restaurants (53).
--   - Restaurants needed to reach 80% of votes, as a count and a % of restaurants.
--   - Share of votes held by the top 20% of restaurants; Gini coefficient.
--   - Most concentrated localities first.
--
-- Grain & rules
--   - Restaurant = distinct URL path (restaurant_id); latest snapshot by votes.
--   - Zero-vote restaurants stay in the denominator: the 80/20 claim is about all restaurants.
--   - Ranking ties break by restaurant_id, so ranks and running totals are deterministic.
--   - "Restaurants for 80%" counts top-down and includes the restaurant that crosses 80%:
--     cum_votes - votes < 0.8 * total_votes.
--   - Fix vs original attempt: it summed votes over listing rows (~4 rows per restaurant,
--     14,671,985 votes vs 2,286,732), grouped by name + location, and dropped zero-vote
--     restaurants. See docs/query_review_log.md.
--
-- Result : results/a09_pareto_by_locality.csv
-- =============================================================================

WITH restaurants AS (                       -- one row per restaurant (see 03_validation/02)
    SELECT
        REGEXP_EXTRACT(url, r'^[^?]+')                                 AS restaurant_id,
        location,
        COALESCE(votes_cleaned, 0)                                     AS votes
    FROM `zomatoanalytics.Zomato_csv.restaurants_clean`
    WHERE url IS NOT NULL
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY REGEXP_EXTRACT(url, r'^[^?]+')
        ORDER BY votes_cleaned DESC, url
    ) = 1
),
scoped AS (                                 -- each locality + the whole city
    SELECT location AS scope, restaurant_id, votes FROM restaurants WHERE location IS NOT NULL
    UNION ALL
    SELECT 'ALL BANGALORE', restaurant_id, votes FROM restaurants
),
ranked AS (
    SELECT
        scope, votes,
        ROW_NUMBER() OVER (PARTITION BY scope ORDER BY votes DESC, restaurant_id)     AS rnk,
        COUNT(*)     OVER (PARTITION BY scope)                                        AS n,
        SUM(votes)   OVER (PARTITION BY scope)                                        AS total_votes,
        SUM(votes)   OVER (PARTITION BY scope ORDER BY votes DESC, restaurant_id
                           ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)          AS cum_votes
    FROM scoped
)
SELECT
    scope,
    n                                                                       AS restaurants,
    COUNTIF(votes = 0)                                                      AS zero_vote_restaurants,
    total_votes,
    COUNTIF(cum_votes - votes < 0.8 * total_votes)                          AS restaurants_for_80_pct,
    ROUND(100 * COUNTIF(cum_votes - votes < 0.8 * total_votes) / n, 1)      AS pct_restaurants_for_80,
    ROUND(100 * SAFE_DIVIDE(SUM(IF(rnk <= CEIL(0.2 * n), votes, 0)), total_votes), 1) AS top20_vote_share_pct,
    ROUND(SAFE_DIVIDE(2 * SUM((n + 1 - rnk) * votes), n * total_votes) - (n + 1) / n, 3) AS gini,
    CASE WHEN 100 * COUNTIF(cum_votes - votes < 0.8 * total_votes) / n < 20
         THEN 'More concentrated than 80/20' ELSE 'Flatter than 80/20' END  AS verdict
FROM ranked
GROUP BY scope, n, total_votes
HAVING scope = 'ALL BANGALORE' OR n >= 50
ORDER BY scope = 'ALL BANGALORE' DESC, pct_restaurants_for_80, scope;
