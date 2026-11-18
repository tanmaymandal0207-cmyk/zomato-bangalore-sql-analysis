-- =============================================================================
-- A11 | Supply gaps: where do restaurants get more engagement than expected?
-- =============================================================================
-- Business question
--   For someone opening a restaurant: which locality x price band combinations
--   draw far more votes per restaurant than expected, i.e. demand per outlet is
--   high relative to supply?
--
-- Requirements
--   - Localities with at least 100 restaurants; cells (locality x price band) with
--     at least 20 restaurants.
--   - Demand index = actual votes per restaurant in the cell / expected votes per
--     restaurant, where expected = locality votes per restaurant x (city votes per
--     restaurant in that band / city votes per restaurant overall).
--     1.0 = as expected; 2.0 = twice the engagement the locality and band predict.
--   - Guard against one famous restaurant driving the cell: exclude cells where the
--     top restaurant holds more than 40% of the cell's votes.
--   - Top 15 cells by demand index, with average rating vs the locality average.
--
-- Grain & rules
--   - Restaurant = distinct URL path (restaurant_id); latest snapshot by votes.
--   - Zero-vote restaurants count as supply. Restaurants with no cost are left out of
--     cells but count in locality and city baselines.
--   - Votes measure engagement, not orders or revenue: treat the index as a screen.
--
-- Result : results/a11_supply_gaps_by_locality.csv
-- =============================================================================

WITH restaurants AS (                       -- one row per restaurant (see 03_validation/02)
    SELECT
        REGEXP_EXTRACT(url, r'^[^?]+')                                 AS restaurant_id,
        location,
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
banded AS (
    SELECT
        location, votes, rating,
        CASE
            WHEN cost_for_two IS NULL  THEN NULL
            WHEN cost_for_two <= 300   THEN '1 Up to Rs 300'
            WHEN cost_for_two <= 600   THEN '2 Rs 301-600'
            WHEN cost_for_two <= 1000  THEN '3 Rs 601-1,000'
            ELSE                            '4 Rs 1,000+'
        END                                                            AS price_band
    FROM restaurants
),
city AS (
    SELECT SUM(votes) / COUNT(*) AS city_vpr FROM banded
),
city_band AS (
    SELECT price_band, SUM(votes) / COUNT(*) AS band_vpr
    FROM banded WHERE price_band IS NOT NULL GROUP BY price_band
),
loc AS (
    SELECT location, COUNT(*) AS loc_restaurants, SUM(votes) / COUNT(*) AS loc_vpr,
           AVG(rating) AS loc_rating
    FROM banded WHERE location IS NOT NULL
    GROUP BY location
    HAVING COUNT(*) >= 100
),
cells AS (
    SELECT
        b.location, b.price_band,
        COUNT(*)                                                            AS restaurants,
        SUM(b.votes)                                                        AS votes,
        MAX(b.votes)                                                        AS top_votes,
        AVG(b.rating)                                                       AS avg_rating
    FROM banded b
    JOIN loc l USING (location)
    WHERE b.price_band IS NOT NULL
    GROUP BY b.location, b.price_band
    HAVING COUNT(*) >= 20
)
SELECT
    c.location,
    SUBSTR(c.price_band, 3)                                                 AS price_band,
    c.restaurants,
    ROUND(100 * c.restaurants / l.loc_restaurants, 1)                       AS pct_of_locality_restaurants,
    c.votes,
    ROUND(c.votes / c.restaurants, 1)                                       AS votes_per_restaurant,
    ROUND(l.loc_vpr * cb.band_vpr / ct.city_vpr, 1)                         AS expected_votes_per_restaurant,
    ROUND((c.votes / c.restaurants) / (l.loc_vpr * cb.band_vpr / ct.city_vpr), 2) AS demand_index,
    ROUND(100 * c.top_votes / c.votes, 1)                                   AS top_restaurant_vote_share_pct,
    ROUND(c.avg_rating, 2)                                                  AS avg_rating,
    ROUND(l.loc_rating, 2)                                                  AS locality_avg_rating
FROM cells c
JOIN loc l USING (location)
JOIN city_band cb USING (price_band)
CROSS JOIN city ct
WHERE c.votes > 0
  AND c.top_votes <= 0.4 * c.votes
ORDER BY demand_index DESC, c.location, c.price_band
LIMIT 15;
