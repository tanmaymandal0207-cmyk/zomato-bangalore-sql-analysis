-- =============================================================================
-- C01 | Popular isn't loved: KPI benchmark (low-rated vs well-rated peers)
-- Feeds   : results/c01_kpi_benchmark.csv
-- Source  : zomatoanalytics.Zomato_csv.restaurants_clean (51,717 listing rows)
-- Grain   : one row per restaurant (restaurant_id = URL path), latest snapshot =
--           listing row with the highest votes_cleaned, ties by url (same as A09c)
-- Scope   : "established" = votes > average votes of restaurants with >= 1 vote
--           (242.08), and rating NOT NULL  -> 1,942 restaurants
-- Groups  : low_rated = rating < 3.5 (165) | peers = rating >= 3.5 (1,777)
-- Chain   : brand (exact name) has >= 5 outlets across all 12,453 restaurants
-- CI      : 95% normal-approximation interval on the difference in proportions
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
        CASE WHEN b.rating < 3.5 THEN 'low_rated' ELSE 'peers' END        AS grp,
        CASE WHEN b.online_order = 'Yes' THEN 1 ELSE 0 END               AS is_online,
        CASE WHEN b.brand_outlets >= 5 THEN 1 ELSE 0 END                 AS is_chain,
        CASE WHEN b.approx_cost_for_two BETWEEN 301 AND 600 THEN 1 ELSE 0 END AS is_mid_price
    FROM with_brand b
    CROSS JOIN threshold t
    WHERE b.votes > t.avg_votes
      AND b.rating IS NOT NULL
),
by_group AS (
    SELECT
        grp,
        COUNT(*)            AS n,
        AVG(is_online)      AS p_online,
        AVG(is_chain)       AS p_chain,
        AVG(is_mid_price)   AS p_mid_price,
        AVG(rating)         AS avg_rating,
        SUM(votes)          AS votes
    FROM established
    GROUP BY grp
),
wide AS (
    SELECT
        MAX(CASE WHEN grp = 'low_rated' THEN n END)           AS n_low,
        MAX(CASE WHEN grp = 'peers'     THEN n END)           AS n_peer,
        MAX(CASE WHEN grp = 'low_rated' THEN p_online END)    AS on_low,
        MAX(CASE WHEN grp = 'peers'     THEN p_online END)    AS on_peer,
        MAX(CASE WHEN grp = 'low_rated' THEN p_chain END)     AS ch_low,
        MAX(CASE WHEN grp = 'peers'     THEN p_chain END)     AS ch_peer,
        MAX(CASE WHEN grp = 'low_rated' THEN p_mid_price END) AS mp_low,
        MAX(CASE WHEN grp = 'peers'     THEN p_mid_price END) AS mp_peer,
        MAX(CASE WHEN grp = 'low_rated' THEN avg_rating END)  AS r_low,
        MAX(CASE WHEN grp = 'peers'     THEN avg_rating END)  AS r_peer,
        MAX(CASE WHEN grp = 'low_rated' THEN votes END)       AS v_low,
        MAX(CASE WHEN grp = 'peers'     THEN votes END)       AS v_peer
    FROM by_group
),
metrics AS (
    SELECT 1 AS sort_order, 'Restaurants' AS metric, 'count' AS unit,
           CAST(n_low AS FLOAT64) AS low_rated, CAST(n_peer AS FLOAT64) AS peers,
           n_low, n_peer, CAST(NULL AS FLOAT64) AS p1, CAST(NULL AS FLOAT64) AS p2 FROM wide
    UNION ALL
    SELECT 2, 'Share of established restaurants', 'pct',
           100 * n_low / (n_low + n_peer), 100 * n_peer / (n_low + n_peer),
           n_low, n_peer, NULL, NULL FROM wide
    UNION ALL
    SELECT 3, 'Average rating', 'rating', r_low, r_peer, n_low, n_peer, NULL, NULL FROM wide
    UNION ALL
    SELECT 4, 'Votes held', 'count', v_low, v_peer, n_low, n_peer, NULL, NULL FROM wide
    UNION ALL
    SELECT 5, 'Online ordering', 'pct', 100 * on_low, 100 * on_peer, n_low, n_peer, on_low, on_peer FROM wide
    UNION ALL
    SELECT 6, 'Chain outlet (brand has 5+ outlets)', 'pct', 100 * ch_low, 100 * ch_peer, n_low, n_peer, ch_low, ch_peer FROM wide
    UNION ALL
    SELECT 7, 'Priced Rs 301-600 for two', 'pct', 100 * mp_low, 100 * mp_peer, n_low, n_peer, mp_low, mp_peer FROM wide
)
SELECT
    sort_order,
    metric,
    unit,
    ROUND(low_rated, 2)                                              AS low_rated,
    ROUND(peers, 2)                                                  AS peers,
    ROUND(low_rated - peers, 2)                                      AS gap,
    ROUND(100 * ((p1 - p2) - 1.96 * SQRT(p1 * (1 - p1) / n_low + p2 * (1 - p2) / n_peer)), 1) AS gap_ci_low_pts,
    ROUND(100 * ((p1 - p2) + 1.96 * SQRT(p1 * (1 - p1) / n_low + p2 * (1 - p2) / n_peer)), 1) AS gap_ci_high_pts,
    ROUND(low_rated / peers, 2)                                      AS ratio
FROM metrics
ORDER BY sort_order;
