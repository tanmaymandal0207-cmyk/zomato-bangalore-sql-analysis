-- =============================================================================
-- A10 | Table booking vs rating
-- =============================================================================
-- Business question
--   Restaurants that take table bookings are rated higher. Is that because booking
--   goes with better restaurants, or only because booking restaurants are expensive?
--
-- Requirements
--   - Average rating with and without table booking: overall, then within each
--     price band for two (Up to Rs 300 / 301-600 / 601-1,000 / 1,000+).
--   - Restaurant counts on both sides, the rating gap and a 95% range for the gap.
--   - A price-adjusted gap: the within-band gaps averaged with each band weighted by
--     its number of restaurants.
--
-- Grain & rules
--   - Restaurant = distinct URL path (restaurant_id); latest snapshot by votes.
--   - Rated restaurants only (rating NOT NULL). Band rows exclude restaurants with no cost.
--   - 95% range: normal approximation, gap +/- 1.96 * sqrt(var_yes/n_yes + var_no/n_no).
--   - Bands with fewer than 30 booking restaurants are flagged 'small base'.
--
-- Result : results/a10_table_booking_vs_rating.csv
-- =============================================================================

WITH restaurants AS (                       -- one row per restaurant (see 03_validation/02)
    SELECT
        REGEXP_EXTRACT(url, r'^[^?]+')                                 AS restaurant_id,
        book_table,
        approx_cost_cleaned                                            AS cost_for_two,
        SAFE_CAST(SPLIT(rate_cleaned, '/')[SAFE_OFFSET(0)] AS FLOAT64) AS rating   -- NEW / '-' / NULL -> NULL
    FROM `zomatoanalytics.Zomato_csv.restaurants_clean`
    WHERE url IS NOT NULL
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY REGEXP_EXTRACT(url, r'^[^?]+')
        ORDER BY votes_cleaned DESC, url
    ) = 1
),
rated AS (
    SELECT
        book_table,
        rating,
        CASE
            WHEN cost_for_two IS NULL  THEN NULL
            WHEN cost_for_two <= 300   THEN '1 Up to Rs 300'
            WHEN cost_for_two <= 600   THEN '2 Rs 301-600'
            WHEN cost_for_two <= 1000  THEN '3 Rs 601-1,000'
            ELSE                            '4 Rs 1,000+'
        END                                                            AS price_band
    FROM restaurants
    WHERE rating IS NOT NULL
),
cells AS (
    SELECT '0 All rated restaurants' AS segment, book_table, rating FROM rated
    UNION ALL
    SELECT price_band, book_table, rating FROM rated WHERE price_band IS NOT NULL
),
stats AS (
    SELECT
        segment,
        COUNTIF(book_table = 'Yes')                                         AS n_booking,
        COUNTIF(book_table = 'No')                                          AS n_no_booking,
        AVG(IF(book_table = 'Yes', rating, NULL))                           AS r_yes,
        AVG(IF(book_table = 'No',  rating, NULL))                           AS r_no,
        VAR_SAMP(IF(book_table = 'Yes', rating, NULL))                      AS v_yes,
        VAR_SAMP(IF(book_table = 'No',  rating, NULL))                      AS v_no
    FROM cells
    GROUP BY segment
),
gaps AS (
    SELECT *,
        r_yes - r_no                                                        AS gap,
        1.96 * SQRT(v_yes / n_booking + v_no / n_no_booking)                AS margin
    FROM stats
),
adjusted AS (                               -- band gaps weighted by band size
    SELECT
        '5 Price-adjusted (weighted by band)'                               AS segment,
        SUM(n_booking)                                                      AS n_booking,
        SUM(n_no_booking)                                                   AS n_no_booking,
        CAST(NULL AS FLOAT64)                                               AS r_yes,
        CAST(NULL AS FLOAT64)                                               AS r_no,
        SUM(gap * (n_booking + n_no_booking)) / SUM(n_booking + n_no_booking) AS gap,
        CAST(NULL AS FLOAT64)                                               AS margin
    FROM gaps
    WHERE segment != '0 All rated restaurants'
)
SELECT
    SUBSTR(seg_code, 3)                                                     AS segment,
    n_booking,
    n_no_booking,
    ROUND(100 * n_booking / (n_booking + n_no_booking), 1)                  AS pct_with_booking,
    ROUND(r_yes, 2)                                                         AS avg_rating_booking,
    ROUND(r_no, 2)                                                          AS avg_rating_no_booking,
    ROUND(gap, 2)                                                           AS rating_gap,
    ROUND(gap - margin, 2)                                                  AS gap_ci_low,
    ROUND(gap + margin, 2)                                                  AS gap_ci_high,
    CASE WHEN n_booking < 30 THEN 'small base' ELSE '' END                  AS base_flag
FROM (
    SELECT segment AS seg_code, n_booking, n_no_booking, r_yes, r_no, gap, margin FROM gaps
    UNION ALL
    SELECT segment, n_booking, n_no_booking, r_yes, r_no, gap, margin FROM adjusted
)
ORDER BY seg_code;
