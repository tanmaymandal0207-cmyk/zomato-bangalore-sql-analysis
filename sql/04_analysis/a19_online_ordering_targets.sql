-- =============================================================================
-- A19 | Online-ordering onboarding targets
-- =============================================================================
-- Business question
--   Sales list for the online-ordering team: which well-rated, popular restaurants
--   in delivery-friendly formats still do not take online orders?
--
-- Requirements
--   - online_order = 'No', rating >= 4.0, votes >= 500.
--   - Delivery-friendly formats only: exclude any restaurant whose rest_type mentions
--     Bar, Pub, Microbrewery, Lounge, Club or Fine Dining.
--   - Top 15 by votes (customers already engaged), with the total count of targets.
--
-- Grain & rules
--   - Restaurant = distinct URL path (restaurant_id); latest snapshot by votes.
--   - Each outlet is a separate target; ties by restaurant_id.
--   - Restaurants with no rest_type are excluded (format unknown).
--
-- Result : results/a19_online_ordering_targets.csv
-- =============================================================================

WITH restaurants AS (                       -- one row per restaurant (see 03_validation/02)
    SELECT
        REGEXP_EXTRACT(url, r'^[^?]+')                                 AS restaurant_id,
        name,
        location,
        rest_type,
        online_order,
        approx_cost_cleaned                                            AS cost_for_two,
        COALESCE(votes_cleaned, 0)                                     AS votes,
        SAFE_CAST(SPLIT(rate_cleaned, '/')[SAFE_OFFSET(0)] AS FLOAT64) AS rating
    FROM `zomatoanalytics.Zomato_csv.restaurants_clean`
    WHERE url IS NOT NULL
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY REGEXP_EXTRACT(url, r'^[^?]+')
        ORDER BY votes_cleaned DESC, url
    ) = 1
),
targets AS (
    SELECT *
    FROM restaurants
    WHERE online_order = 'No'
      AND rating >= 4.0
      AND votes >= 500
      AND rest_type IS NOT NULL
      AND NOT REGEXP_CONTAINS(rest_type, r'Bar|Pub|Microbrewery|Lounge|Club|Fine Dining')
)
SELECT
    ROW_NUMBER() OVER (ORDER BY votes DESC, restaurant_id)             AS priority,
    name,
    location,
    rest_type,
    cost_for_two,
    votes,
    rating,
    COUNT(*) OVER ()                                                   AS total_targets
FROM targets
WHERE TRUE                                  -- BigQuery needs WHERE/GROUP BY/HAVING with QUALIFY
QUALIFY priority <= 15
ORDER BY priority;
