-- =============================================================================
-- A12 | Chains vs independents
-- =============================================================================
-- Business question
--   Do chain outlets out-perform independent restaurants? Compare rating, quality
--   mix, engagement, price and online ordering, overall and by format.
--
-- Requirements
--   - Chain = brand name (exact match) with 5 or more outlets city-wide; all other
--     restaurants are independent (including 2-4 outlet groups).
--   - Format = first value of the multi-valued rest_type. Overall + the 7 largest
--     formats: Quick Bites, Casual Dining, Delivery, Takeaway, Dessert Parlor, Cafe, Bakery.
--   - Per segment: restaurants, rated restaurants, average rating, % rated 4.0+,
--     median votes, % online ordering, average cost for two.
--
-- Grain & rules
--   - Restaurant = distinct URL path (restaurant_id); latest snapshot by votes.
--   - Median votes use PERCENTILE_CONT (exact), not APPROX_QUANTILES.
--   - Ratings: NEW / '-' / NULL excluded from averages and from the 4.0+ base.
--   - Known issue: 11 residual duplicate URLs (same name, location and votes) can add
--     one outlet to a brand's count; no brand crosses the 5-outlet line because of it.
--
-- Result : results/a12_chains_vs_independents.csv
-- =============================================================================

WITH restaurants AS (                       -- one row per restaurant (see 03_validation/02)
    SELECT
        REGEXP_EXTRACT(url, r'^[^?]+')                                 AS restaurant_id,
        name,
        rest_type,
        online_order,
        approx_cost_cleaned                                            AS cost_for_two,
        COALESCE(votes_cleaned, 0)                                     AS votes,
        SAFE_CAST(SPLIT(rate_cleaned, '/')[SAFE_OFFSET(0)] AS FLOAT64) AS rating   -- NEW / '-' / NULL -> NULL
    FROM `zomatoanalytics.Zomato_csv.restaurants_clean`
    WHERE url IS NOT NULL
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY REGEXP_EXTRACT(url, r'^[^?]+')
        ORDER BY votes_cleaned DESC, url
    ) = 1
),
typed AS (
    SELECT
        *,
        IF(COUNT(*) OVER (PARTITION BY name) >= 5, 'Chain (5+ outlets)', 'Independent') AS segment,
        TRIM(REGEXP_EXTRACT(rest_type, r'^[^,]+'))                          AS format
    FROM restaurants
),
cells AS (
    SELECT 'All restaurants' AS format, segment, votes, rating, online_order, cost_for_two FROM typed
    UNION ALL
    SELECT format, segment, votes, rating, online_order, cost_for_two FROM typed
    WHERE format IN ('Quick Bites', 'Casual Dining', 'Delivery', 'Takeaway',
                     'Dessert Parlor', 'Cafe', 'Bakery')
),
with_median AS (
    SELECT *, PERCENTILE_CONT(votes, 0.5) OVER (PARTITION BY format, segment) AS median_votes
    FROM cells
)
SELECT
    format,
    segment,
    COUNT(*)                                                                AS restaurants,
    COUNT(rating)                                                           AS rated_restaurants,
    ROUND(AVG(rating), 2)                                                   AS avg_rating,
    ROUND(100 * COUNTIF(rating >= 4) / COUNT(rating), 1)                    AS pct_rated_4_plus,
    ROUND(ANY_VALUE(median_votes), 1)                                       AS median_votes,
    ROUND(100 * COUNTIF(online_order = 'Yes') / COUNT(*), 1)                AS pct_online,
    ROUND(AVG(cost_for_two), 0)                                             AS avg_cost_for_two
FROM with_median
GROUP BY format, segment
ORDER BY format != 'All restaurants', format, segment;
