-- =============================================================================
-- C02 | Where low-rated popular restaurants concentrate: price band x format
-- Feeds   : results/c02_low_rated_by_price_and_format.csv
-- Grain, scope and group rules: identical to C01 (see that header)
--   established = votes > avg votes of voted restaurants (242.08), rating NOT NULL
--   low-rated   = rating < 3.5 ; chain = brand (exact name) with 5+ outlets city-wide
-- Format  : main_type = first value of rest_type. Bases < 15 flagged, not dropped.
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
cells AS (
    SELECT 'All established' AS format, price_band, band_order, is_low_rated, rating FROM established
    UNION ALL
    SELECT main_type, price_band, band_order, is_low_rated, rating FROM established
    WHERE main_type IN ('Quick Bites', 'Casual Dining')
)
SELECT
    format,
    price_band,
    band_order,
    COUNT(*)                                                         AS restaurants,
    SUM(is_low_rated)                                                AS low_rated,
    ROUND(100 * AVG(is_low_rated), 1)                                AS low_rated_rate_pct,
    ROUND(AVG(rating), 2)                                            AS avg_rating,
    ROUND(100 * SUM(is_low_rated) / SUM(SUM(is_low_rated)) OVER (PARTITION BY format), 1) AS share_of_low_rated_pct,
    CASE WHEN COUNT(*) < 15 THEN 'small base' ELSE '' END            AS base_flag
FROM cells
GROUP BY format, price_band, band_order
ORDER BY CASE format WHEN 'All established' THEN 1 WHEN 'Quick Bites' THEN 2 ELSE 3 END, band_order;
