-- =============================================================================
-- C04 | Priority list: the 165 popular, low-rated restaurants
-- Feeds   : results/c04_priority_list.csv
-- Grain, scope and group rules: identical to C01 (see that header)
--   established = votes > avg votes of voted restaurants (242.08), rating NOT NULL
--   low-rated   = rating < 3.5 ; chain = brand (exact name) with 5+ outlets city-wide
-- Priority: votes DESC (most customers exposed first), ties by restaurant_id
-- Dup flag: same name + location + votes on another URL path (residual duplicate)
-- =============================================================================

WITH restaurants AS (
    -- @@GRAIN_START
    SELECT
        REGEXP_EXTRACT(url, r'^[^?]+')                                 AS restaurant_id,
        name,
        location,
        rest_type,
        online_order,
        book_table,
        approx_cost_cleaned                                            AS approx_cost_for_two,
        COALESCE(votes_cleaned, 0)                                     AS votes,
        SAFE_CAST(SPLIT(rate_cleaned, '/')[SAFE_OFFSET(0)] AS FLOAT64) AS rating
    FROM `zomatoanalytics.Zomato_csv.restaurants_clean`
    WHERE url IS NOT NULL
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY REGEXP_EXTRACT(url, r'^[^?]+')
        ORDER BY votes_cleaned DESC, url
    ) = 1
    -- @@GRAIN_END
),
with_brand AS (
    SELECT *, COUNT(*) OVER (PARTITION BY name) AS brand_outlets
    FROM restaurants
),
threshold AS (
    SELECT AVG(votes) AS avg_votes FROM restaurants WHERE votes > 0
),
established AS (
    SELECT
        b.*,
        CASE WHEN b.rating < 3.5 THEN 1 ELSE 0 END                         AS is_low_rated,
        TRIM(REGEXP_EXTRACT(b.rest_type, r'^[^,]+'))                       AS main_type,
        CASE
            WHEN b.approx_cost_for_two IS NULL  THEN 'Not listed'
            WHEN b.approx_cost_for_two <= 300   THEN 'Up to Rs 300'
            WHEN b.approx_cost_for_two <= 600   THEN 'Rs 301-600'
            WHEN b.approx_cost_for_two <= 1000  THEN 'Rs 601-1,000'
            ELSE 'Rs 1,000+'
        END                                                                AS price_band,
        CASE
            WHEN b.approx_cost_for_two IS NULL  THEN 5
            WHEN b.approx_cost_for_two <= 300   THEN 1
            WHEN b.approx_cost_for_two <= 600   THEN 2
            WHEN b.approx_cost_for_two <= 1000  THEN 3
            ELSE 4
        END                                                                AS band_order
    FROM with_brand b
    CROSS JOIN threshold t
    WHERE b.votes > t.avg_votes
      AND b.rating IS NOT NULL
)
,
dup_check AS (
    SELECT restaurant_id,
           COUNT(*) OVER (PARTITION BY name, location, votes) AS same_name_location_votes
    FROM with_brand
)
SELECT
    ROW_NUMBER() OVER (ORDER BY votes DESC, restaurant_id)           AS priority_rank,
    restaurant_id,
    name,
    location,
    main_type,
    price_band,
    approx_cost_for_two,
    online_order,
    brand_outlets,
    CASE WHEN brand_outlets >= 5 THEN 'Yes' ELSE 'No' END            AS chain_5_plus,
    votes,
    rating,
    CASE WHEN d.same_name_location_votes > 1
         THEN 'Yes' ELSE 'No' END                                    AS possible_duplicate
FROM established
JOIN dup_check d USING (restaurant_id)
WHERE is_low_rated = 1
ORDER BY priority_rank;
