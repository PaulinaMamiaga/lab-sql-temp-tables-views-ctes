-- LAB | Temporary Tables, Views and CTEs (Sakila)
-- Database: Sakila (MySQL)
-- -------------------------------------------------
-- Goal:
-- Build a customer summary report that includes:
-- - customer_name
-- - email
-- - rental_count
-- - total_paid
-- - average_payment_per_rental (derived from total_paid / rental_count)

-- We will do it in 3 steps:
-- 1) Create a VIEW to summarize rentals per customer
-- 2) Create a TEMPORARY TABLE to summarize payments per customer
-- 3) Use a CTE to join both and generate the final report
-- --------------------------------------------------------------------------
USE sakila;
-- -------------------------------------------------------------------
-- STEP 1: Create a VIEW
-- ----------------------------------------------------------------
-- What I want:
-- A reusable "virtual table" with one row per customer, showing:
-- - customer_id
-- - customer_name
-- - email
-- - rental_count (how many rentals they made)

-- Why a VIEW?
-- Because it simplifies later queries: I can reuse this logic without rewriting it.
-- ------------------------------------------------------------------------------------
-- If the view already exists, I drop it first
DROP VIEW IF EXISTS v_customer_rental_summary;
-- --------------------------------------------------------------------------------------
-- Now I create the view
-- ------------------------------------------
CREATE VIEW v_customer_rental_summary AS
SELECT
    c.customer_id,
    CONCAT(c.first_name, ' ', c.last_name) AS customer_name,
    c.email,
    COUNT(r.rental_id) AS rental_count
FROM customer AS c
-- LEFT JOIN keeps customers even if they have zero rentals
LEFT JOIN rental AS r
    ON c.customer_id = r.customer_id
GROUP BY
    c.customer_id,
    c.first_name,
    c.last_name,
    c.email;

-- ----------------------------------------------------------------------------------
-- STEP 2: Create a TEMPORARY TABLE
-- ---------------------------------------------------------------------------------
-- What I want:
-- A table that stores the total amount paid by each customer:
-- - customer_id
-- - total_paid

-- Why a TEMPORARY TABLE?
-- Because it stores intermediate results for my session. It can help keep my final query clean and can be useful for performance or reusability inside the session.
-- ------------------------------------------------------------------------------------------------------------------------------------------------------------------------
-- If the temporary table exists in my current session, I drop it first
DROP TEMPORARY TABLE IF EXISTS temp_customer_payment_summary;

-- Create the temporary table using the rental summary view + payment table
CREATE TEMPORARY TABLE temp_customer_payment_summary AS
SELECT
    v.customer_id,
    -- SUM() adds all payments per customer; ROUND() formats to 2 decimals
    ROUND(SUM(p.amount), 2) AS total_paid
FROM v_customer_rental_summary AS v
-- LEFT JOIN keeps customers even if they have no payments
LEFT JOIN payment AS p
    ON v.customer_id = p.customer_id
GROUP BY
    v.customer_id;

-- -----------------------------------------------------------------------------
-- STEP 3: Create a CTE and generate the final customer summary report
-- ------------------------------------------------------------------------------
-- What I want in the final report:
-- - customer_name
-- - email
-- - rental_count
-- - total_paid
-- - average_payment_per_rental

-- Important detail:
-- Some customers can have rental_count = 0 (because of LEFT JOIN in the view).
-- So, avoid division by zero when computing the average.
-- ----------------------------------------------------------------------------- 

WITH customer_summary AS (
    SELECT
        v.customer_name,
        v.email,
        v.rental_count,

        -- If total_paid is NULL (no payments), I convert it to 0
        COALESCE(t.total_paid, 0) AS total_paid
    FROM v_customer_rental_summary AS v
    LEFT JOIN temp_customer_payment_summary AS t
        ON v.customer_id = t.customer_id
)
SELECT
    customer_name,
    email,
    rental_count,
    total_paid,

    -- average_payment_per_rental = total_paid / rental_count
    -- I use CASE to avoid dividing by zero when rental_count = 0
    ROUND(
        CASE
            WHEN rental_count = 0 THEN 0
            ELSE total_paid / rental_count
        END
    , 2) AS average_payment_per_rental
FROM customer_summary
-- Ordering helps me read the output: biggest payers first
ORDER BY total_paid DESC, rental_count DESC;
