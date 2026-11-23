-- ============================================================
-- Chinook Music Store Revenue Analysis (SQLite)
-- Author: Imanathul Reyyan
-- Question: Which artists, genres and countries earn the most?
-- ============================================================


-- ============================================================
-- STEP 1: DATA CHECK
-- ============================================================

-- 1.1 How big is each table?
SELECT 'Artist' AS tbl, COUNT(*) AS row_count FROM Artist
UNION ALL SELECT 'Album', COUNT(*) FROM Album
UNION ALL SELECT 'Track', COUNT(*) FROM Track
UNION ALL SELECT 'Genre', COUNT(*) FROM Genre
UNION ALL SELECT 'Customer', COUNT(*) FROM Customer
UNION ALL SELECT 'Invoice', COUNT(*) FROM Invoice
UNION ALL SELECT 'InvoiceLine', COUNT(*) FROM InvoiceLine;


-- 1.2 What period does the data cover, and what is the total revenue?
SELECT MIN(InvoiceDate) AS first_invoice,
       MAX(InvoiceDate) AS last_invoice,
       COUNT(*)         AS invoices,
       ROUND(SUM(Total), 2) AS total_revenue
FROM Invoice;


-- 1.3 Do invoice totals match the sum of their invoice lines?
SELECT COUNT(*) AS mismatched_invoices
FROM Invoice i
WHERE ABS(i.Total - (SELECT SUM(l.UnitPrice * l.Quantity)
                     FROM InvoiceLine l
                     WHERE l.InvoiceId = i.InvoiceId)) > 0.001;


-- 1.4 Does every track belong to an album (do the joins hold)?
SELECT COUNT(*) AS tracks_without_album
FROM Track t
LEFT JOIN Album a ON a.AlbumId = t.AlbumId
WHERE a.AlbumId IS NULL;


-- ============================================================
-- STEP 2: REVENUE BY COUNTRY
-- ============================================================

-- 2.1 Which countries earn the most revenue?
SELECT BillingCountry                          AS country,
       COUNT(*)                                AS invoices,
       COUNT(DISTINCT CustomerId)              AS customers,
       ROUND(SUM(Total), 2)                    AS revenue,
       ROUND(100.0 * SUM(Total) / (SELECT SUM(Total) FROM Invoice), 1) AS pct_of_total,
       ROUND(AVG(Total), 2)                    AS avg_invoice
FROM Invoice
GROUP BY BillingCountry
ORDER BY revenue DESC
LIMIT 10;


-- 2.2 Which countries earn the most per customer (a fairer comparison)?
SELECT c.Country                                        AS country,
       COUNT(DISTINCT c.CustomerId)                     AS customers,
       ROUND(SUM(i.Total), 2)                           AS revenue,
       ROUND(SUM(i.Total) / COUNT(DISTINCT c.CustomerId), 2) AS revenue_per_customer
FROM Invoice i
JOIN Customer c ON c.CustomerId = i.CustomerId
GROUP BY c.Country
ORDER BY revenue_per_customer DESC
LIMIT 6;


-- ============================================================
-- STEP 3: REVENUE BY GENRE
-- ============================================================

-- 3.1 Which genres earn the most revenue?
SELECT g.Name                                   AS genre,
       COUNT(*)                                 AS tracks_sold,
       ROUND(SUM(il.UnitPrice * il.Quantity), 2) AS revenue,
       ROUND(100.0 * SUM(il.UnitPrice * il.Quantity)
             / (SELECT SUM(UnitPrice * Quantity) FROM InvoiceLine), 1) AS pct_of_total
FROM InvoiceLine il
JOIN Track t ON t.TrackId = il.TrackId
JOIN Genre g ON g.GenreId = t.GenreId
GROUP BY g.GenreId
ORDER BY revenue DESC
LIMIT 10;


-- 3.2 Which genres sell best for the size of their catalogue?
SELECT g.Name                                       AS genre,
       COUNT(DISTINCT t.TrackId)                    AS tracks_in_catalogue,
       COUNT(il.InvoiceLineId)                      AS tracks_sold,
       ROUND(1.0 * COUNT(il.InvoiceLineId) / COUNT(DISTINCT t.TrackId), 2) AS sold_per_track
FROM Genre g
JOIN Track t ON t.GenreId = g.GenreId
LEFT JOIN InvoiceLine il ON il.TrackId = t.TrackId
GROUP BY g.GenreId
HAVING COUNT(il.InvoiceLineId) > 0
ORDER BY sold_per_track DESC
LIMIT 6;


-- ============================================================
-- STEP 4: REVENUE BY ARTIST
-- ============================================================

-- 4.1 Which artists earn the most revenue?
SELECT ar.Name                                    AS artist,
       COUNT(*)                                   AS tracks_sold,
       ROUND(SUM(il.UnitPrice * il.Quantity), 2)  AS revenue,
       ROUND(100.0 * SUM(il.UnitPrice * il.Quantity)
             / (SELECT SUM(UnitPrice * Quantity) FROM InvoiceLine), 1) AS pct_of_total
FROM InvoiceLine il
JOIN Track  t  ON t.TrackId  = il.TrackId
JOIN Album  al ON al.AlbumId = t.AlbumId
JOIN Artist ar ON ar.ArtistId = al.ArtistId
GROUP BY ar.ArtistId
ORDER BY revenue DESC
LIMIT 10;


-- 4.2 Which music artists earn the most, once TV shows (video) are excluded?
SELECT ar.Name                                    AS artist,
       COUNT(*)                                   AS tracks_sold,
       ROUND(SUM(il.UnitPrice * il.Quantity), 2)  AS revenue
FROM InvoiceLine il
JOIN Track     t  ON t.TrackId      = il.TrackId
JOIN MediaType m  ON m.MediaTypeId  = t.MediaTypeId
JOIN Album     al ON al.AlbumId     = t.AlbumId
JOIN Artist    ar ON ar.ArtistId    = al.ArtistId
WHERE m.Name NOT LIKE '%video%'
GROUP BY ar.ArtistId
ORDER BY revenue DESC
LIMIT 10;


-- 4.3 How concentrated is revenue: what share do the top 10 artists hold?
WITH top10 AS (
    SELECT ar.Name AS artist,
           SUM(il.UnitPrice * il.Quantity) AS revenue
    FROM InvoiceLine il
    JOIN Track  t  ON t.TrackId  = il.TrackId
    JOIN Album  al ON al.AlbumId = t.AlbumId
    JOIN Artist ar ON ar.ArtistId = al.ArtistId
    GROUP BY ar.ArtistId
    ORDER BY revenue DESC
    LIMIT 10
)
SELECT ROUND(SUM(revenue), 2) AS top10_revenue,
       ROUND(100.0 * SUM(revenue) / (SELECT SUM(UnitPrice * Quantity) FROM InvoiceLine), 1) AS pct_of_total
FROM top10;


-- ============================================================
-- STEP 5: CUSTOMER INSIGHTS
-- ============================================================

-- 5.1 Who are the top 10 customers by total spend?
SELECT c.FirstName || ' ' || c.LastName  AS customer,
       c.Country                         AS country,
       COUNT(i.InvoiceId)                AS invoices,
       ROUND(SUM(i.Total), 2)            AS total_spent
FROM Customer c
JOIN Invoice i ON i.CustomerId = c.CustomerId
GROUP BY c.CustomerId
ORDER BY total_spent DESC, customer
LIMIT 10;


-- 5.2 How much does a typical customer spend, and how wide is the range?
WITH spend AS (
    SELECT CustomerId, SUM(Total) AS total_spent
    FROM Invoice
    GROUP BY CustomerId
)
SELECT COUNT(*)                     AS customers,
       ROUND(MIN(total_spent), 2)   AS lowest,
       ROUND(AVG(total_spent), 2)   AS average,
       ROUND(MAX(total_spent), 2)   AS highest
FROM spend;


-- 5.3 What share of revenue do the top 10 customers generate?
WITH top10 AS (
    SELECT CustomerId, SUM(Total) AS total_spent
    FROM Invoice
    GROUP BY CustomerId
    ORDER BY total_spent DESC
    LIMIT 10
)
SELECT ROUND(SUM(total_spent), 2) AS top10_revenue,
       ROUND(100.0 * SUM(total_spent) / (SELECT SUM(Total) FROM Invoice), 1) AS pct_of_total
FROM top10;


-- 5.4 Do customers come back: how many invoices does each customer have?
SELECT invoices_per_customer,
       COUNT(*) AS customers
FROM (
    SELECT CustomerId, COUNT(*) AS invoices_per_customer
    FROM Invoice
    GROUP BY CustomerId
)
GROUP BY invoices_per_customer
ORDER BY invoices_per_customer;


-- ============================================================
-- STEP 6: TIME TREND
-- ============================================================

-- 6.1 How does revenue change year by year?
SELECT STRFTIME('%Y', InvoiceDate)  AS year,
       COUNT(*)                     AS invoices,
       ROUND(SUM(Total), 2)         AS revenue
FROM Invoice
GROUP BY year
ORDER BY year;


-- 6.2 What is the year-over-year revenue growth?
WITH yearly AS (
    SELECT STRFTIME('%Y', InvoiceDate) AS year,
           SUM(Total)                  AS revenue
    FROM Invoice
    GROUP BY year
)
SELECT year,
       ROUND(revenue, 2) AS revenue,
       ROUND(100.0 * (revenue - LAG(revenue) OVER (ORDER BY year))
             / LAG(revenue) OVER (ORDER BY year), 1) AS growth_pct
FROM yearly
ORDER BY year;


-- 6.3 Is there a seasonal pattern: which calendar months earn the most?
SELECT STRFTIME('%m', InvoiceDate)  AS month,
       COUNT(*)                     AS invoices,
       ROUND(SUM(Total), 2)         AS revenue
FROM Invoice
GROUP BY month
ORDER BY month;


-- ============================================================
-- STEP 7: ADVANCED (CTEs, WINDOW FUNCTIONS, SUBQUERIES)
-- ============================================================

-- 7.1 Who is the top-earning artist within each of the top 5 genres?
WITH genre_revenue AS (
    SELECT t.GenreId, g.Name AS genre,
           SUM(il.UnitPrice * il.Quantity) AS revenue
    FROM InvoiceLine il
    JOIN Track t ON t.TrackId = il.TrackId
    JOIN Genre g ON g.GenreId = t.GenreId
    GROUP BY t.GenreId
    ORDER BY revenue DESC
    LIMIT 5
),
artist_genre AS (
    SELECT t.GenreId, ar.Name AS artist,
           SUM(il.UnitPrice * il.Quantity) AS revenue
    FROM InvoiceLine il
    JOIN Track  t  ON t.TrackId  = il.TrackId
    JOIN Album  al ON al.AlbumId = t.AlbumId
    JOIN Artist ar ON ar.ArtistId = al.ArtistId
    GROUP BY t.GenreId, ar.ArtistId
),
ranked AS (
    SELECT GenreId, artist, ROUND(revenue, 2) AS revenue,
           RANK() OVER (PARTITION BY GenreId ORDER BY revenue DESC) AS rnk
    FROM artist_genre
)
SELECT gr.genre, r.artist, r.revenue
FROM ranked r
JOIN genre_revenue gr ON gr.GenreId = r.GenreId
WHERE r.rnk = 1
ORDER BY r.revenue DESC;


-- 7.2 In how many countries is each genre the number one genre?
WITH country_genre AS (
    SELECT i.BillingCountry AS country, g.Name AS genre,
           SUM(il.UnitPrice * il.Quantity) AS revenue
    FROM InvoiceLine il
    JOIN Invoice i ON i.InvoiceId = il.InvoiceId
    JOIN Track   t ON t.TrackId   = il.TrackId
    JOIN Genre   g ON g.GenreId   = t.GenreId
    GROUP BY i.BillingCountry, g.Name
),
ranked AS (
    SELECT country, genre,
           RANK() OVER (PARTITION BY country ORDER BY revenue DESC) AS rnk
    FROM country_genre
)
SELECT genre, COUNT(*) AS countries_ranked_first
FROM ranked
WHERE rnk = 1
GROUP BY genre
ORDER BY countries_ranked_first DESC;


-- 7.3 What is the running (cumulative) revenue month by month?
WITH monthly AS (
    SELECT STRFTIME('%Y-%m', InvoiceDate) AS year_month,
           SUM(Total) AS revenue
    FROM Invoice
    GROUP BY year_month
)
SELECT year_month,
       ROUND(revenue, 2) AS revenue,
       ROUND(SUM(revenue) OVER (ORDER BY year_month), 2) AS running_total
FROM monthly
ORDER BY year_month;


-- 7.4 Which genres have never been sold? (subquery)
SELECT Name AS genre_never_sold
FROM Genre
WHERE GenreId NOT IN (SELECT t.GenreId
                      FROM Track t
                      JOIN InvoiceLine il ON il.TrackId = t.TrackId);


-- 7.5 How much of the catalogue has never been sold? (subquery)
SELECT COUNT(*) AS tracks_never_sold,
       ROUND(100.0 * COUNT(*) / (SELECT COUNT(*) FROM Track), 1) AS pct_of_catalogue
FROM Track
WHERE TrackId NOT IN (SELECT TrackId FROM InvoiceLine);
