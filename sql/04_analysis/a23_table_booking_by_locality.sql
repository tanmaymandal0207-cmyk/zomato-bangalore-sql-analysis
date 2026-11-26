-- =============================================================================
-- A23 | Table booking adoption by locality
-- =============================================================================
-- Business question
--   For a table-reservation product: in which large localities do restaurants
--   already take bookings, and where is adoption low despite good ratings?
--
-- Requirements
--   - Localities with at least 300 restaurants.
--   - Restaurants, % taking table bookings, average rating, % rated 4.0+.
--   - Highest booking adoption first.
--
-- Grain & rules
--   - Restaurant = distinct URL path (restaurant_id); latest snapshot by votes.
--   - % rated 4.0+ uses rated restaurants as the base.
--
-- Result : results/a23_table_booking_by_locality.csv
-- =============================================================================

WITH restaurants AS (                       -- one row per restaurant (see 03_validation/02)
    SELECT
        REGEXP_EXTRACT(url, r'^[^?]+')                                 AS restaurant_id,
        location,
        book_table,
        SAFE_CAST(SPLIT(rate_cleaned, '/')[SAFE_OFFSET(0)] AS FLOAT64) AS rating
    FROM `zomatoanalytics.Zomato_csv.restaurants_clean`
    WHERE url IS NOT NULL
    QUALIFY ROW_NUMBER() OVER (
        PARTITION BY REGEXP_EXTRACT(url, r'^[^?]+')
        ORDER BY votes_cleaned DESC, url
    ) = 1
)
SELECT
    location,
    COUNT(*)                                                           AS restaurants,
    ROUND(100 * COUNTIF(book_table = 'Yes') / COUNT(*), 1)             AS pct_table_booking,
    ROUND(AVG(rating), 2)                                              AS avg_rating,
    ROUND(100 * COUNTIF(rating >= 4.0) / COUNT(rating), 1)             AS pct_rated_4_plus
FROM restaurants
WHERE location IS NOT NULL
GROUP BY location
HAVING COUNT(*) >= 300
ORDER BY pct_table_booking DESC, location;
