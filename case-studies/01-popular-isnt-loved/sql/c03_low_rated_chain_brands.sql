-- =============================================================================
-- C03 | Brand or outlet? Chains with low-rated popular outlets
-- Feeds   : results/c03_low_rated_chain_brands.csv
-- Grain, scope and group rules: identical to C01 (see that header)
--   established = votes > avg votes of voted restaurants (242.08), rating NOT NULL
--   low-rated   = rating < 3.5 ; chain = brand (exact name) with 5+ outlets city-wide
-- Output  : every chain brand with >= 1 low-rated established outlet
--           brand_avg_rating        = mean rating of ALL the brand's rated outlets
--           other_outlets_avg_rating = mean rating of the brand's rated outlets that
--                                      are NOT on the low-rated list
--           diagnosis: other outlets >= 3.5 -> 'Outlet execution' else 'Brand-wide'
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
),
low_ids AS (
    SELECT restaurant_id FROM established WHERE is_low_rated = 1
),
brand_all AS (
    SELECT
        w.name,
        AVG(w.rating)                                                    AS brand_avg_rating,
        AVG(CASE WHEN l.restaurant_id IS NULL THEN w.rating END)         AS other_outlets_avg_rating
    FROM with_brand w
    LEFT JOIN low_ids l USING (restaurant_id)
    WHERE w.rating IS NOT NULL
    GROUP BY w.name
)
SELECT
    e.name                                                           AS brand,
    COUNT(*)                                                         AS low_rated_outlets,
    MAX(e.brand_outlets)                                             AS brand_outlets,
    ROUND(100 * COUNT(*) / MAX(e.brand_outlets), 1)                  AS pct_outlets_low_rated,
    SUM(e.votes)                                                     AS votes_on_low_rated_outlets,
    ROUND(AVG(e.rating), 2)                                          AS avg_rating_low_rated_outlets,
    ROUND(MAX(a.brand_avg_rating), 2)                                AS brand_avg_rating,
    ROUND(MAX(a.other_outlets_avg_rating), 2)                        AS other_outlets_avg_rating,
    CASE WHEN MAX(a.other_outlets_avg_rating) >= 3.5
         THEN 'Outlet execution' ELSE 'Brand-wide' END               AS diagnosis
FROM established e
JOIN brand_all a USING (name)
WHERE e.is_low_rated = 1
  AND e.brand_outlets >= 5
GROUP BY e.name
ORDER BY low_rated_outlets DESC, votes_on_low_rated_outlets DESC, brand;
